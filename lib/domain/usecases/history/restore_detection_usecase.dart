import '../../../core/utils/result.dart';
import '../../models/detection_result.dart';
import '../../repositories/i_detection_repository.dart';

class RestoreDetectionUseCase {
  final IDetectionRepository _repository;

  RestoreDetectionUseCase(this._repository);

  Future<Result<int>> call(DetectionResult detection) async {
    return await _repository.saveDetection(detection);
  }
}
