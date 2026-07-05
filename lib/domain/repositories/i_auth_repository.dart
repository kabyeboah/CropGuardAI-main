import '../../core/utils/result.dart';
import '../models/app_user.dart';

abstract class IAuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  bool get isSignedIn;
  bool get isAnonymous;

  Future<Result<AppUser>> signIn({required String email, required String password});
  Future<Result<AppUser>> register({required String email, required String password, required String name});
  Future<Result<void>> signInWithGoogle();
  Future<Result<void>> signInAnonymously();
  Future<Result<void>> signOut();
  Future<Result<void>> deleteAccount();
  Future<Result<void>> sendPasswordReset(String email);

  /// Validates a reset code from the deep link, returning the target email.
  Future<Result<String>> verifyPasswordResetCode(String code);

  /// Completes an in-app password reset using the deep-link code.
  Future<Result<void>> confirmPasswordReset({
    required String code,
    required String newPassword,
  });

  Future<Result<void>> updateDisplayName(String name);
  Future<Result<void>> updatePhotoUrl(String url);
}
