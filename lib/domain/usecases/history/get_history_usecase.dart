import '../../../core/utils/result.dart';
import '../../models/detection_result.dart';
import '../../repositories/i_detection_repository.dart';

class GetHistoryUseCase {
  final IDetectionRepository _repository;

  GetHistoryUseCase(this._repository);

  Future<Result<List<DetectionResult>>> call({String? userId}) {
    return _repository.getHistory(userId: userId);
  }
}
