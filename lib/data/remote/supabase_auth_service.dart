import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import '../../core/config/app_secrets.dart';
import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/retry_utils.dart';


/// Wraps Supabase Auth — replaces FirebaseAuthService
class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;



  User? get currentUser => _client.auth.currentUser;
  
  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) => data.session?.user);

  bool get isSignedIn => _client.auth.currentUser != null;
  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? false;

  bool get hasPasswordProvider =>
      _client.auth.currentUser?.appMetadata['provider'] == 'email' ||
      _client.auth.currentUser?.identities?.any((i) => i.provider == 'email') == true;

  bool get hasGoogleProvider =>
      _client.auth.currentUser?.appMetadata['provider'] == 'google' ||
      _client.auth.currentUser?.identities?.any((i) => i.provider == 'google') == true;

  bool _isAuthTransientError(Object error) {
    if (error is AuthException) {
      final code = error.statusCode;
      if (code == '500' || code == '503' || code == '504' || code == '429') {
        return true;
      }
    }
    return error is TimeoutException || error is SocketException;
  }

  // ─── Email / Password ─────────────────────────────────────────────────
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await RetryUtils.retry(
        () => _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      AppLogger.e('Supabase sign-in AuthException: ${e.message} (code: ${e.code ?? e.statusCode})');
      throw AuthFailure(
        e.message,
        code: e.code ?? e.statusCode ?? 'auth_error',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Sign in failed: ${e.toString()}');
    }
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await RetryUtils.retry(
        () => _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': name.trim()},
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
      return response;
    } on AuthException catch (e) {
      AppLogger.e('Supabase register AuthException: ${e.message} (code: ${e.code ?? e.statusCode})');
      throw AuthFailure(
        e.message,
        code: e.code ?? e.statusCode ?? 'auth_error',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Registration failed: ${e.toString()}');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await RetryUtils.retry(
        () => _client.auth.resetPasswordForEmail(
          email.trim(),
          redirectTo: AppSecrets.passwordResetContinueUrl,
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      throw AuthFailure(
        e.message,
        code: e.code ?? e.statusCode ?? 'auth_error',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Password reset failed: ${e.toString()}');
    }
  }

  Future<void> exchangeCodeForSession(String code) async {
    if (code.trim().isEmpty) return;
    try {
      await RetryUtils.retry(
        () => _client.auth.exchangeCodeForSession(code.trim()),
        maxAttempts: 2,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      AppLogger.w('exchangeCodeForSession AuthException: ${e.message}');
      throw AuthFailure(e.message, code: e.code ?? e.statusCode ?? 'auth_error');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Failed to exchange reset code: $e');
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      if (code.trim().isNotEmpty) {
        try {
          await _client.auth.exchangeCodeForSession(code.trim());
        } catch (_) {
          // Session may have already been established by Supabase deep-link listener
        }
      }
      await RetryUtils.retry(
        () => _client.auth.updateUser(
          UserAttributes(password: newPassword),
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      AppLogger.e('Supabase confirmPasswordReset error: ${e.message}');
      throw AuthFailure(
        e.message,
        code: e.code ?? e.statusCode ?? 'auth_error',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Password reset failed: ${e.toString()}');
    }
  }

  // ─── Google Sign-In (Supabase OAuth web flow) ─────────────────────────
  // Opens browser → Google OAuth → Supabase callback → deep-links back via
  // io.supabase.cropguard://login-callback/
  // No google-services.json / SHA-1 matching required.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: (Platform.isAndroid || Platform.isIOS)
            ? 'io.supabase.cropguard://login-callback/'
            : null,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // Wait for the auth state change triggered by the deep-link callback
      final completer = Completer<AuthResponse>();
      late StreamSubscription<AuthState> sub;
      sub = _client.auth.onAuthStateChange.listen((data) {
        if (data.session != null && !completer.isCompleted) {
          sub.cancel();
          completer.complete(AuthResponse(
            session: data.session,
            user: data.session!.user,
          ));
        }
      });
      // Allow up to 3 minutes for the user to complete the browser flow
      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          sub.cancel();
          throw const AuthFailure(
            'Google sign-in timed out. Please try again.',
            code: 'timeout',
          );
        },
      );
    } on AuthException catch (e) {
      AppLogger.e('Supabase Google sign-in AuthException: ${e.message}');
      throw AuthFailure(
        e.message,
        code: e.code ?? e.statusCode ?? 'auth_error',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      AppLogger.e('Google sign-in unexpected error: $e');
      throw AuthFailure('Google sign-in failed: ${e.toString()}');
    }
  }


  // ─── Anonymous Guest ──────────────────────────────────────────────────
  Future<AuthResponse> signInAnonymously() async {
    try {
      return await RetryUtils.retry(
        () => _client.auth.signInAnonymously(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      AppLogger.e('Supabase anonymous sign-in error: ${e.message}');
      throw AuthFailure(
        e.message,
        code: e.statusCode ?? 'auth_error',
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Anonymous sign-in failed: ${e.toString()}');
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await RetryUtils.retry(
        () => _client.auth.signOut(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 10),
        retryIf: _isAuthTransientError,
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Sign out failed: ${e.toString()}');
    }
  }


  // ─── Re-authentication ────────────────────────────────────────────────
  Future<void> reauthenticateWithPassword(String password) async {
    final email = currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthFailure('No email account to re-authenticate');
    }
    await signIn(email: email, password: password);
  }

  Future<void> reauthenticateWithGoogle() async {
    await signInWithGoogle();
  }

  Future<void> deleteAccount() async {
    try {
      await signOut();
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Delete account failed: ${e.toString()}');
    }
  }

  // ─── Update Profile ───────────────────────────────────────────────────
  Future<void> updateDisplayName(String name) async {
    try {
      await RetryUtils.retry(
        () => _client.auth.updateUser(
          UserAttributes(
            data: {'full_name': name.trim()},
          ),
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 10),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.statusCode ?? 'update_error');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Update display name failed: ${e.toString()}');
    }
  }

  Future<void> updatePhotoUrl(String url) async {
    try {
      await RetryUtils.retry(
        () => _client.auth.updateUser(
          UserAttributes(
            data: {'avatar_url': url.trim()},
          ),
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 10),
        retryIf: _isAuthTransientError,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.statusCode ?? 'update_error');
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Update photo URL failed: ${e.toString()}');
    }
  }

  String? get currentUserIdOrNull => _client.auth.currentUser?.id;

  String get currentUserId {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthFailure('No authenticated user found.');
    }
    return uid;
  }

  String get currentUserEmail => _client.auth.currentUser?.email ?? '';
  String get currentUserName {
    final user = _client.auth.currentUser;
    if (user == null) return 'Farmer';
    final metadata = user.userMetadata;
    return metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        'Farmer';
  }
  String? get currentUserPhotoUrl {
    final metadata = _client.auth.currentUser?.userMetadata;
    return metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?;
  }
}
