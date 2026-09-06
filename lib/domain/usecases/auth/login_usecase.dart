import '../../../core/error/failures.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/utils/result.dart';
import '../../models/app_user.dart';
import '../../repositories/i_auth_repository.dart';

class LoginUseCase {
  final IAuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Result<AppUser>> call(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      return Future.value(
          Result.error(const AuthFailure('Please fill in all fields.')));
    }
    if (!EmailValidator.isValid(normalizedEmail)) {
      return Future.value(Result.error(
          const AuthFailure('Please enter a valid email address.')));
    }
    return _repository.signIn(email: normalizedEmail, password: password);
  }
}
