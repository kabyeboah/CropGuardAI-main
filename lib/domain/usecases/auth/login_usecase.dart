import '../../../core/utils/result.dart';
import '../../models/app_user.dart';
import '../../repositories/i_auth_repository.dart';

class LoginUseCase {
  final IAuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Result<AppUser>> call(String email, String password) {
    return _repository.signIn(email: email, password: password);
  }
}
