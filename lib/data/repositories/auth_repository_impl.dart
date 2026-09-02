import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/di/service_locator.dart';
import '../../core/error/failures.dart';
import '../../core/utils/push_notification_service.dart';
import '../../core/utils/result.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_community_repository.dart';
import 'community_repository_impl.dart';
import '../remote/supabase_auth_service.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final SupabaseAuthService _authService;

  AuthRepositoryImpl(this._authService);

  @override
  Stream<AppUser?> get authStateChanges =>
      _authService.authStateChanges.map(_mapSupabaseUser);

  @override
  AppUser? get currentUser => _mapSupabaseUser(_authService.currentUser);

  @override
  bool get isSignedIn => _authService.isSignedIn;

  @override
  bool get isAnonymous => _authService.isAnonymous;

  @override
  Future<Result<AppUser>> signIn(
      {required String email, required String password}) async {
    try {
      final response =
          await _authService.signIn(email: email, password: password);
      final user = _mapSupabaseUser(response.user);
      if (user != null) {
        return Result.success(user);
      } else {
        return Result.error(const AuthFailure('Sign in failed: User is null'));
      }
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<AppUser>> register(
      {required String email,
      required String password,
      required String name}) async {
    try {
      final response = await _authService.register(
          email: email, password: password, name: name);
      final user = _mapSupabaseUser(response.user);
      if (user != null) {
        final effectiveUser =
            (user.displayName.isEmpty || user.displayName == 'Farmer') &&
                    name.trim().isNotEmpty
                ? user.copyWith(displayName: name.trim())
                : user;
        return Result.success(effectiveUser);
      } else {
        return Result.error(
            const AuthFailure('Registration failed: User is null'));
      }
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signInWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signInAnonymously() async {
    try {
      await _authService.signInAnonymously();
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      final uid = _authService.currentUserIdOrNull;
      if (uid != null) {
        try {
          await PushNotificationService.clearFcmToken(uid)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      try {
        if (sl.isRegistered<ICommunityRepository>()) {
          final repo = sl<ICommunityRepository>();
          if (repo is CommunityRepositoryImpl) {
            await repo.drainPendingSync().timeout(const Duration(seconds: 4));
          }
        }
      } catch (_) {
        // Best-effort drain; do not block sign-out if offline or timed out
      }
      await _authService.signOut();
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      final uid = _authService.currentUserIdOrNull;
      if (uid != null) {
        try {
          await PushNotificationService.clearFcmToken(uid)
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      await _authService.signOut();
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> verifyPasswordResetCode(String code) async {
    try {
      final trimmed = code.trim();
      if (trimmed.isNotEmpty) {
        try {
          await _authService.exchangeCodeForSession(trimmed);
        } catch (_) {
          // May already be in recovery session
        }
      }
      if (_authService.isSignedIn) {
        return Result.success(_authService.currentUserEmail);
      }
      if (trimmed.isNotEmpty) {
        return Result.success('');
      }
      return Result.error(const AuthFailure('Invalid or expired reset code'));
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _authService.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateDisplayName(String name) async {
    try {
      await _authService.updateDisplayName(name);
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updatePhotoUrl(String url) async {
    try {
      await _authService.updatePhotoUrl(url);
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  bool get hasPasswordProvider => _authService.hasPasswordProvider;

  @override
  bool get hasGoogleProvider => _authService.hasGoogleProvider;

  @override
  Future<Result<void>> reauthenticateWithPassword(String password) async {
    try {
      await _authService.reauthenticateWithPassword(password);
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> reauthenticateWithGoogle() async {
    try {
      await _authService.reauthenticateWithGoogle();
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(AuthFailure(e.toString()));
    }
  }

  AppUser? _mapSupabaseUser(supabase.User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    final name = metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        'Farmer';
    final photo =
        metadata?['avatar_url'] as String? ?? metadata?['picture'] as String?;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: name,
      photoUrl: photo,
      isAnonymous: user.isAnonymous,
    );
  }
}
