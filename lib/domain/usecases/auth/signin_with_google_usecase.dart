import '../../../core/utils/result.dart';
import '../../repositories/i_auth_repository.dart';

class SignInWithGoogleUseCase {
  final IAuthRepository _repository;

  SignInWithGoogleUseCase(this._repository);

  Future<Result<void>> call() {
    return _repository.signInWithGoogle();
  }
}
