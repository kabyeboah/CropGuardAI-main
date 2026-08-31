import '../../../core/error/failures.dart';
import '../../../core/utils/email_validator.dart';
import '../../../core/utils/result.dart';
import '../../models/app_user.dart';
import '../../repositories/i_auth_repository.dart';

class RegisterUseCase {
  final IAuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Result<AppUser>> call({
    required String email,
    required String password,
    required String name,
  }) {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return Future.value(Result.error(
          const AuthFailure('Please fill in all required fields.')));
    }
    if (!EmailValidator.isValid(email)) {
      return Future.value(Result.error(
          const AuthFailure('Please enter a valid email address.')));
    }
    if (password.length < 8) {
      return Future.value(Result.error(
          const AuthFailure('Password must be at least 8 characters long.')));
    }
    return _repository.register(
      email: email,
      password: password,
      name: name,
    );
  }
}
