import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/local/database_helper.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../domain/usecases/auth/login_usecase.dart';
import '../../../domain/usecases/auth/signin_with_google_usecase.dart';
import '../../../domain/usecases/auth/signin_anonymously_usecase.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/utils/analytics_service.dart';

enum LoginStatus { idle, loading, success, error }

class LoginProvider extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final SignInWithGoogleUseCase _googleUseCase;
  final SignInAnonymouslyUseCase _guestUseCase;
  final DatabaseHelper _db;
  final FirebaseAuthService _auth;
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

  Future<void> signIn(
    String email,
    String password,
    VoidCallback onSuccess, {
    void Function(int count)? onMigrationNeeded,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      errorMessage = 'Please fill in all fields.';
      notifyListeners();
      return;
    }
    if (!EmailValidator.isValid(email)) {
      errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return;
    }
    await _captureAnonState();
    status = LoginStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _loginUseCase(email, password);
    if (result.isSuccess) {
      status = LoginStatus.success;
      unawaited(_analytics.logLogin(method: 'email'));
      notifyListeners();
      _handlePostSignIn(onSuccess, onMigrationNeeded);
    } else {
      status = LoginStatus.error;
      errorMessage = _mapFailure(result.failure!.message);
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
      _handlePostSignIn(onSuccess, onMigrationNeeded);
    } else {
      status = LoginStatus.error;
      errorMessage = 'Google sign-in failed. Please try again.';
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
      onSuccess();
    } else {
      status = LoginStatus.error;
      errorMessage = 'Guest sign-in failed.';
      notifyListeners();
    }
  }

  Future<void> acceptMigration() async {
    if (_anonUid != null) {
      await _db.reassignDetections(_anonUid!, _auth.currentUserId);
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

  String _mapFailure(String e) {
    if (e.contains('wrong-password') || e.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (e.contains('user-not-found')) return 'No account found with that email.';
    if (e.contains('network-request-failed')) return 'No internet connection.';
    return 'Sign-in failed. Please try again.';
  }
}
