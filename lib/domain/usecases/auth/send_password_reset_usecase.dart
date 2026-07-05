import '../../../core/utils/result.dart';
import '../../repositories/i_auth_repository.dart';

class SendPasswordResetUseCase {
  final IAuthRepository _repository;

  SendPasswordResetUseCase(this._repository);

  Future<Result<void>> call(String email) {
    return _repository.sendPasswordReset(email);
  }
}
