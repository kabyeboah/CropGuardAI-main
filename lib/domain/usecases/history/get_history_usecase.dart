import '../../../core/utils/result.dart';
import '../../models/detection_result.dart';
import '../../repositories/i_detection_repository.dart';

class GetHistoryUseCase {
  final IDetectionRepository _repository;

  GetHistoryUseCase(this._repository);

  Future<Result<List<DetectionResult>>> call({
    String? userId,
    int? limit,
    int? offset,
    bool? isHealthy,
    List<String>? cropTypes,
    int? dateFrom,
    int? dateTo,
    String? searchQuery,
    String? orderBy,
  }) {
    return _repository.getHistory(
      userId: userId,
      limit: limit,
      offset: offset,
      isHealthy: isHealthy,
      cropTypes: cropTypes,
      dateFrom: dateFrom,
      dateTo: dateTo,
      searchQuery: searchQuery,
      orderBy: orderBy,
    );
  }

  Future<Result<List<String>>> getDistinctCropTypes({String? userId}) {
    return _repository.getDistinctCropTypes(userId: userId);
  }
}
