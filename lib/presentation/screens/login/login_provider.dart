import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../../data/remote/supabase_auth_service.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../../domain/usecases/auth/signin_with_google_usecase.dart';
import '../../../domain/usecases/auth/signin_anonymously_usecase.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/utils/analytics_service.dart';

enum LoginStatus { idle, loading, success, error }

class LoginProvider extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final SignInWithGoogleUseCase _googleUseCase;
  final SignInAnonymouslyUseCase _guestUseCase;
  final DatabaseHelper _db;
  final SupabaseAuthService _auth;
  final AnalyticsService _analytics;

  LoginProvider(
    this._loginUseCase,
    this._googleUseCase,
    this._guestUseCase,
    this._db,
    this._auth,
    this._analytics,
  );

  String? errorMessage;

  // ── Guest migration state ──────────────────────────────────────────────────
  String? _anonUid;
  int _anonScanCount = 0;
  VoidCallback? _pendingOnSuccess;

  LoginStatus status = LoginStatus.idle;

  int get anonScanCount => _anonScanCount;

  void reset() {
    status = LoginStatus.idle;
    errorMessage = null;
    _anonUid = null;
    _anonScanCount = 0;
    _pendingOnSuccess = null;
    notifyListeners();
  }

  Future<void> _captureAnonState() async {
    if (!_auth.isAnonymous) {
      _anonUid = null;
      _anonScanCount = 0;
      return;
    }
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

  Future<void> signIn(
    String email,
    String password,
    VoidCallback onSuccess, {
    void Function(int count)? onMigrationNeeded,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      errorMessage = 'Please fill in all fields.';
      notifyListeners();
      return;
    }
    if (!EmailValidator.isValid(normalizedEmail)) {
      errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return;
    }
    await _captureAnonState();
    status = LoginStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _loginUseCase(normalizedEmail, password);
    if (result.isSuccess) {
      status = LoginStatus.success;
      unawaited(_analytics.logLogin(method: 'email'));
      notifyListeners();
      // Post-microtask: let auth state changes emit so the GoRouter
      // refreshListenable (AuthStateNotifier) updates isSignedIn before
      // onSuccess calls context.go('/home').
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _handlePostSignIn(onSuccess, onMigrationNeeded);
    } else {
      status = LoginStatus.error;
      AppLogger.e('LoginProvider signIn error: ${result.failure}');
      errorMessage = _mapFailure(result.failure);
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle(
    VoidCallback onSuccess, {
    void Function(int count)? onMigrationNeeded,
  }) async {
    await _captureAnonState();
    status = LoginStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _googleUseCase();
    if (result.isSuccess) {
      status = LoginStatus.success;
      unawaited(_analytics.logLogin(method: 'google'));
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _handlePostSignIn(onSuccess, onMigrationNeeded);
    } else {
      status = LoginStatus.error;
      final f = result.failure;
      AppLogger.e('LoginProvider Google sign-in error: $f');
      if (f is AuthFailure && f.code == 'cancelled') {
        errorMessage = 'Google sign-in was cancelled.';
      } else if (f is AuthFailure && f.code == 'invalid-credential') {
        errorMessage =
            'Google sign-in configuration error. '
            'Please ensure your app OAuth client ID and SHA-1 certificate are properly configured.';
      } else {
        errorMessage = _mapFailure(f);
      }
      notifyListeners();
    }
  }

  Future<void> signInAsGuest(VoidCallback onSuccess) async {
    status = LoginStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _guestUseCase();
    if (result.isSuccess) {
      status = LoginStatus.success;
      unawaited(_analytics.logLogin(method: 'anonymous'));
      unawaited(_analytics.setUser(isAnonymous: true));
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      onSuccess();
    } else {
      status = LoginStatus.error;
      AppLogger.e('LoginProvider guest sign-in error: ${result.failure}');
      errorMessage = _mapFailure(result.failure);
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

  String _mapFailure(Failure? failure) {
    if (failure == null) return 'Sign-in failed. Please try again.';

    final code = (failure is AuthFailure) ? failure.code : null;
    final e = failure.message.toLowerCase();

    // Log the error code and message for diagnostics.
    AppLogger.e(
      'LoginProvider error: code="${code ?? 'none'}" '
      'message="${failure.message}"',
    );

    if (code == 'cancelled' || e.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }

    if (code == 'email_not_confirmed' ||
        e.contains('email not confirmed') ||
        e.contains('email_not_confirmed')) {
      return 'Email not confirmed. Please check your inbox and verify your email before signing in.';
    }

    if (code == 'INVALID_LOGIN_CREDENTIALS' ||
        code == 'invalid_credentials' ||
        code == 'invalid_grant' ||
        e.contains('invalid_login_credentials') ||
        e.contains('invalid login credentials') ||
        e.contains('invalid_credentials') ||
        e.contains('invalid_grant') ||
        e.contains('wrong-password') ||
        e.contains('invalid-credential') ||
        e.contains('user-not-found') ||
        e.contains('invalid credential') ||
        e.contains('no user record') ||
        e.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (code == 'user-disabled' ||
        code == 'user_banned' ||
        e.contains('user-disabled') ||
        e.contains('user is banned') ||
        e.contains('user_banned')) {
      return 'This user account has been disabled.';
    }
    if (code == 'invalid-email' ||
        e.contains('invalid-email') ||
        e.contains('badly formatted') ||
        e.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (code == 'network-request-failed' ||
        e.contains('network-request-failed') ||
        e.contains('socketexception') ||
        e.contains('network error') ||
        e.contains('failed host lookup') ||
        e.contains('clientexception')) {
      return 'No internet connection. Please check your network.';
    }
    if (code == 'too-many-requests' ||
        code == 'over_email_send_rate_limit' ||
        e.contains('too-many-requests') ||
        e.contains('rate limit') ||
        e.contains('over_email_send_rate_limit')) {
      return 'Access temporarily disabled due to many failed attempts. Please try again later or reset password.';
    }
    if (e.contains('database error saving new user') ||
        e.contains('database error')) {
      return 'Database error saving user. Please update the handle_new_user trigger in Supabase SQL Editor.';
    }
    if (e.contains('apiexception: 10') || e.contains('apiexception: 12500')) {
      return 'Google sign-in configuration error. Please ensure SHA-1 fingerprint and OAuth Client IDs match.';
    }

    if (failure.message.isNotEmpty &&
        !failure.message.startsWith('Sign in failed: Instance of') &&
        !failure.message.startsWith('Instance of')) {
      return failure.message;
    }
    return 'Sign-in failed. Please try again.';
  }
}
