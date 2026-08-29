import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_secrets.dart';
import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/retry_utils.dart';

/// Wraps FirebaseAuth — equivalent of AuthRepositoryImpl + use cases
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Deep-link target for the password-reset email. Firebase appends the
  /// `oobCode`/`mode` query params to this URL; the app intercepts it as an
  /// Android App Link / iOS Universal Link and handles the reset in-app
  /// (see DeepLinkService + docs/PASSWORD_RESET_DEEPLINK.md).
  ///
  /// Values are resolved from [AppSecrets] (dart-define > .env > Remote Config >
  /// fallback) so they can be patched without a store release.
  String get _passwordResetContinueUrl => AppSecrets.passwordResetContinueUrl;
  String get _androidPackageName => AppSecrets.androidPackageName;
  String get _iosBundleId => AppSecrets.iosBundleId;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  bool _isAuthTransientError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
        case 'too-many-requests':
        case 'internal-error':
        case 'service-unavailable':
          return true;
        default:
          return false;
      }
    }
    return error is TimeoutException || error is SocketException;
  }

  // ─── Email / Password ─────────────────────────────────────────────────
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await RetryUtils.retry(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Authentication failed (code: ${e.code})');
    } catch (e) {
      throw AuthFailure('Sign in failed: ${e.toString()}');
    }
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final UserCredential credential;
    try {
      credential = await RetryUtils.retry(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Registration failed (code: ${e.code})');
    } catch (e) {
      throw AuthFailure('Registration failed: ${e.toString()}');
    }

    if (name.trim().isNotEmpty) {
      try {
        await RetryUtils.retry(
          () => credential.user?.updateDisplayName(name.trim()),
          maxAttempts: 3,
          timeout: const Duration(seconds: 10),
          retryIf: _isAuthTransientError,
        );
      } catch (e) {
        // Non-fatal: the account was already created in Firebase Auth.
        // Don't fail the whole registration if display-name update fails
        // on intermittent / low connectivity networks.
        AppLogger.w('Failed to update display name after registration: $e');
      }
    }

    return credential;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await RetryUtils.retry(
        () => _auth.sendPasswordResetEmail(
          email: email.trim(),
          actionCodeSettings: ActionCodeSettings(
            url: _passwordResetContinueUrl,
            handleCodeInApp: true,
            androidPackageName: _androidPackageName,
            androidInstallApp: true,
            androidMinimumVersion: '1',
            iOSBundleId: _iosBundleId,
          ),
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Password reset failed (code: ${e.code})');
    } catch (e) {
      throw AuthFailure('Password reset failed: ${e.toString()}');
    }
  }

  /// Validates a password-reset `oobCode` from the deep link; returns the email
  /// the code is for. Throws if the code is invalid or expired.
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await RetryUtils.retry(
        () => _auth.verifyPasswordResetCode(code),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure('Invalid or expired code: ${e.message}');
    } catch (e) {
      throw AuthFailure('Verification failed: ${e.toString()}');
    }
  }

  /// Completes the in-app password reset using the `oobCode` from the link.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await RetryUtils.retry(
        () => _auth.confirmPasswordReset(code: code, newPassword: newPassword),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure('Failed to reset password: ${e.message}');
    } catch (e) {
      throw AuthFailure('Confirmation failed: ${e.toString()}');
    }
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────
  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn().timeout(const Duration(seconds: 30));
      if (googleUser == null) throw const AuthFailure('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication.timeout(const Duration(seconds: 15));
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await RetryUtils.retry(
        () => _auth.signInWithCredential(credential),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Google authentication failed (code: ${e.code})');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Google sign-in failed: ${e.toString()}');
    }
  }

  // ─── Anonymous ────────────────────────────────────────────────────────
  Future<UserCredential> signInAnonymously() async {
    try {
      return await RetryUtils.retry(
        () => _auth.signInAnonymously(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Anonymous sign-in failed (code: ${e.code})');
    } catch (e) {
      throw AuthFailure('Anonymous sign-in failed: ${e.toString()}');
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 10));
      await RetryUtils.retry(
        () => _auth.signOut(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 10),
        retryIf: _isAuthTransientError,
      );
    } catch (e) {
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }

  // ─── Re-authentication ────────────────────────────────────────────────
  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  bool get hasGoogleProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        throw const AuthFailure('No email account to re-authenticate');
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await RetryUtils.retry(
        () => user.reauthenticateWithCredential(credential),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Re-authentication failed (code: ${e.code})');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Re-authentication failed: ${e.toString()}');
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn().timeout(const Duration(seconds: 30));
      if (googleUser == null) throw const AuthFailure('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication.timeout(const Duration(seconds: 15));
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('No user signed in');
      await RetryUtils.retry(
        () => user.reauthenticateWithCredential(credential),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Re-authentication failed (code: ${e.code})');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Re-authentication failed: ${e.toString()}');
    }
  }

  // ─── Delete Account ───────────────────────────────────────────────────
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('No user signed in');
      await RetryUtils.retry(
        () => user.delete(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Delete account failed (code: ${e.code})');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Delete account failed: ${e.toString()}');
    }
  }

  // ─── Update Profile ───────────────────────────────────────────────────
  Future<void> updateDisplayName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('No user signed in');
      await RetryUtils.retry(
        () => user.updateDisplayName(name),
        maxAttempts: 3,
        timeout: const Duration(seconds: 10),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Update display name failed (code: ${e.code})');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Update display name failed: ${e.toString()}');
    }
  }

  Future<void> updatePhotoUrl(String url) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('No user signed in');
      await RetryUtils.retry(
        () => user.updatePhotoURL(url),
        maxAttempts: 3,
        timeout: const Duration(seconds: 10),
        retryIf: _isAuthTransientError,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Update photo URL failed (code: ${e.code})');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Update photo URL failed: ${e.toString()}');
    }
  }

  String? get currentUserIdOrNull => _auth.currentUser?.uid;

  String get currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AuthFailure('No authenticated user found.');
    }
    return uid;
  }
  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentUserName =>
      _auth.currentUser?.displayName ?? 'Farmer';
  String? get currentUserPhotoUrl => _auth.currentUser?.photoURL;
}
