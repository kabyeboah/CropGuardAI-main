import '../../../core/utils/result.dart';
import '../../repositories/i_detection_repository.dart';

class DeleteDetectionUseCase {
  final IDetectionRepository _repository;

  DeleteDetectionUseCase(this._repository);

  Future<Result<void>> call(int id) {
    return _repository.deleteDetection(id);
  }
}
