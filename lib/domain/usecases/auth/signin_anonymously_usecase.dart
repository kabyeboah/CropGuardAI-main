import '../../../core/utils/result.dart';
import '../../repositories/i_auth_repository.dart';

class SignInAnonymouslyUseCase {
  final IAuthRepository _repository;

  SignInAnonymouslyUseCase(this._repository);

  Future<Result<void>> call() {
    return _repository.signInAnonymously();
  }
}
