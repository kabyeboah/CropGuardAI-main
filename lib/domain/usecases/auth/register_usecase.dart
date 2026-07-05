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
    return _repository.register(
      email: email,
      password: password,
      name: name,
    );
  }
}
