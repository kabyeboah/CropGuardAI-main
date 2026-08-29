import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../core/di/service_locator.dart';
import '../../core/error/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_community_repository.dart';
import 'community_repository_impl.dart';
import '../remote/firebase_auth_service.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final FirebaseAuthService _authService;

  AuthRepositoryImpl(this._authService);

  @override
  Stream<AppUser?> get authStateChanges => _authService.authStateChanges.map(_mapFirebaseUser);

  @override
  AppUser? get currentUser => _mapFirebaseUser(_authService.currentUser);

  @override
  bool get isSignedIn => _authService.isSignedIn;

  @override
  bool get isAnonymous => _authService.isAnonymous;

  @override
  Future<Result<AppUser>> signIn({required String email, required String password}) async {
    try {
      final credential = await _authService.signIn(email: email, password: password);
      final user = _mapFirebaseUser(credential.user);
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
  Future<Result<AppUser>> register({required String email, required String password, required String name}) async {
    try {
      final credential = await _authService.register(email: email, password: password, name: name);
      final user = _mapFirebaseUser(credential.user);
      if (user != null) {
        final effectiveUser = (user.displayName.isEmpty || user.displayName == 'Farmer') && name.trim().isNotEmpty
            ? user.copyWith(displayName: name.trim())
            : user;
        return Result.success(effectiveUser);
      } else {
        return Result.error(const AuthFailure('Registration failed: User is null'));
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
      await _authService.deleteAccount();
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
      final email = await _authService.verifyPasswordResetCode(code);
      return Result.success(email);
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
          code: code, newPassword: newPassword);
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

  AppUser? _mapFirebaseUser(firebase_auth.User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Farmer',
      photoUrl: user.photoURL,
      isAnonymous: user.isAnonymous,
    );
  }
}
