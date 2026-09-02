import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/analytics_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/email_validator.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/remote/supabase_auth_service.dart';
import '../../../domain/usecases/auth/register_usecase.dart';
import '../../../domain/usecases/auth/signin_with_google_usecase.dart';

enum RegisterStatus { idle, loading, success, error }

class RegisterProvider extends ChangeNotifier {
  final RegisterUseCase _registerUseCase;
  final DatabaseHelper _db;
  final SupabaseAuthService _auth;
  final SignInWithGoogleUseCase? _googleUseCase;
  final AnalyticsService? _analytics;

  RegisterProvider(
    this._registerUseCase,
    this._db,
    this._auth, [
    this._googleUseCase,
    this._analytics,
  ]);

  RegisterStatus status = RegisterStatus.idle;
  String? errorMessage;
  bool needsEmailConfirmation = false;
  String? confirmationEmail;


  // ── Guest migration state ──────────────────────────────────────────────────
  String? _anonUid;
  int _anonScanCount = 0;
  VoidCallback? _pendingOnSuccess;

  int get anonScanCount => _anonScanCount;

  Future<void> _captureAnonState() async {
    if (!_auth.isAnonymous) return;
    _anonUid = _auth.currentUserId;
    _anonScanCount = await _db.countDetectionsForUser(_anonUid!);
  }

  void _handlePostSignIn(
    VoidCallback onSuccess,
    void Function(int count)? onMigrationNeeded,
  ) {
    if (_anonScanCount > 0 && onMigrationNeeded != null) {
      _pendingOnSuccess = onSuccess;
      onMigrationNeeded(_anonScanCount);
    } else {
      _anonUid = null;
      _anonScanCount = 0;
      onSuccess();
    }
  }

  /// [onMigrationNeeded] is called instead of [onSuccess] when the user was
  /// a guest with saved scans. Call [acceptMigration] or [declineMigration]
  /// from the dialog to complete the flow and trigger navigation.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required bool termsAccepted,
    required VoidCallback onSuccess,
    void Function(int count)? onMigrationNeeded,
  }) async {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      errorMessage = 'Please fill in all fields.';
      notifyListeners();
      return;
    }
    if (!EmailValidator.isValid(email)) {
      errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return;
    }
    if (password != confirmPassword) {
      errorMessage = 'Passwords do not match.';
      notifyListeners();
      return;
    }
    if (!termsAccepted) {
      errorMessage = 'Please accept the terms and privacy policy.';
      notifyListeners();
      return;
    }
    if (password.length < 8) {
      errorMessage = 'Password must be at least 8 characters.';
      notifyListeners();
      return;
    }

    await _captureAnonState();

    status = RegisterStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result =
        await _registerUseCase(email: email, password: password, name: name);

    if (result.isSuccess) {
      status = RegisterStatus.success;
      if (_analytics != null) {
        unawaited(_analytics.logLogin(method: 'email'));
      }
      // Supabase requires email confirmation by default.
      // When confirmation is enabled, signUp returns a user but no session.
      // Detect this and show a "check your inbox" message instead of
      // navigating to home (which would fail with no active session).
      final isConfirmed = _auth.isSignedIn;
      if (!isConfirmed) {
        needsEmailConfirmation = true;
        confirmationEmail = email.trim();
        notifyListeners();
        return;
      }
      notifyListeners();
      // Wait for authStateChanges to propagate before navigating.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _handlePostSignIn(onSuccess, onMigrationNeeded);
    } else {
      status = RegisterStatus.error;
      errorMessage = _mapError(result.failure!);
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle(
    VoidCallback onSuccess, {
    void Function(int count)? onMigrationNeeded,
  }) async {
    await _captureAnonState();
    status = RegisterStatus.loading;
    errorMessage = null;
    notifyListeners();

    if (_googleUseCase == null) {
      try {
        await _auth.signInWithGoogle();
        status = RegisterStatus.success;
        if (_analytics != null) {
          unawaited(_analytics.logLogin(method: 'google'));
        }
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        _handlePostSignIn(onSuccess, onMigrationNeeded);
      } catch (e) {
        status = RegisterStatus.error;
        if (e is Failure) {
          errorMessage = _mapError(e);
        } else {
          errorMessage = 'Google sign-up failed. Please try again.';
        }
        notifyListeners();
      }
      return;
    }

    final result = await _googleUseCase();
    if (result.isSuccess) {
      status = RegisterStatus.success;
      if (_analytics != null) {
        unawaited(_analytics.logLogin(method: 'google'));
      }
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _handlePostSignIn(onSuccess, onMigrationNeeded);
    } else {
      status = RegisterStatus.error;
      errorMessage = _mapError(result.failure!);
      notifyListeners();
    }
  }

  Future<void> acceptMigration() async {
    if (_anonUid != null) {
      await _db.reassignUserData(_anonUid!, _auth.currentUserId);
    }
    _completeMigration();
  }

  void declineMigration() => _completeMigration();

  void _completeMigration() {
    _anonUid = null;
    _anonScanCount = 0;
    final fn = _pendingOnSuccess;
    _pendingOnSuccess = null;
    notifyListeners();
    fn?.call();
  }

  String _mapError(Failure failure) {
    final code = (failure is AuthFailure) ? failure.code : null;
    final msg = failure.message.toLowerCase();

    // Always log the raw code in debug so developers can see exactly what
    // Firebase returned — especially useful for tracking new error codes.
    AppLogger.e(
      'RegisterProvider: Firebase error code="${code ?? 'none'}" '
      'message="${failure.message}"',
    );

    if (code == 'cancelled' || msg.contains('cancelled')) {
      return 'Google sign-up was cancelled.';
    }
    if (code == 'email-already-in-use' ||
        msg.contains('email-already-in-use') ||
        msg.contains('already in use')) {
      return 'An account already exists with that email.';
    }
    // Firebase returns INVALID_LOGIN_CREDENTIALS when email enumeration
    // protection is enabled — it replaces email-already-in-use.
    if (code == 'INVALID_LOGIN_CREDENTIALS' ||
        code == 'invalid-credential' ||
        msg.contains('invalid_login_credentials') ||
        msg.contains('invalid login credentials')) {
      return 'An account already exists with that email, or the credentials are invalid.';
    }
    if (code == 'weak-password' ||
        msg.contains('weak-password') ||
        msg.contains('password should be at least')) {
      return 'Password is too weak. Please use at least 8 characters.';
    }
    if (code == 'invalid-email' ||
        msg.contains('invalid-email') ||
        msg.contains('badly formatted')) {
      return 'Please enter a valid email address.';
    }
    if (code == 'operation-not-allowed' ||
        code == 'sign-up-not-allowed' ||
        code == 'CONFIGURATION_NOT_FOUND' ||
        msg.contains('operation-not-allowed') ||
        msg.contains('sign-up-not-allowed') ||
        msg.contains('configuration_not_found')) {
      return 'Registration is currently disabled. Please contact support.';
    }
    if (code == 'network-request-failed' ||
        msg.contains('network') ||
        msg.contains('socketexception')) {
      return 'No internet connection. Please check your network.';
    }
    if (code == 'too-many-requests' || msg.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (failure.message.isNotEmpty &&
        !failure.message.startsWith('Registration failed: Instance of') &&
        !failure.message.startsWith('Sign in failed: Instance of')) {
      return failure.message;
    }
    return 'Registration failed. Please try again.';
  }
}
