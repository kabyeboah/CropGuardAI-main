import '../../../core/utils/result.dart';
import '../../repositories/i_auth_repository.dart';

class LogoutUseCase {
  final IAuthRepository _repository;

  LogoutUseCase(this._repository);

  Future<Result<void>> call() {
    return _repository.signOut();
  }
}
