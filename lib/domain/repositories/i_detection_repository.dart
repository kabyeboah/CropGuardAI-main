import '../../core/utils/result.dart';
import '../models/detection_result.dart';
import '../models/field.dart';

abstract class IDetectionRepository {
  Future<Result<int>> saveDetection(DetectionResult result);
  Future<Result<List<DetectionResult>>> getHistory({
    String? userId,
    int? limit,
    int? offset,
    bool? isHealthy,
    List<String>? cropTypes,
    int? dateFrom,
    int? dateTo,
    String? searchQuery,
    String? orderBy,
    bool? isSynced,
  });
  Future<Result<List<DetectionResult>>> getUnsyncedDetections({String? userId});
  Future<Result<void>> markDetectionSynced(int id, {int? syncedAt});
  Future<Result<void>> markDetectionsSynced(List<int> ids, {int? syncedAt});
  Future<Result<DetectionResult?>> getDetection(int id);
  Future<Result<List<DetectionResult>>> getRecentDetections(
      {String? userId, int limit = 5});
  Future<Result<void>> deleteDetection(int id);
  Future<Result<void>> clearHistory();

  // Stats
  Future<Result<Map<String, int>>> getFarmStats({String? userId});
  Future<Result<List<Map<String, dynamic>>>> getDailyTrend(
      {int days = 7, String? userId});

  // Fields
  Future<Result<void>> saveField(Field field);
  Future<Result<List<Field>>> getFields({String? userId});
  Future<Result<void>> deleteField(String id);
  Future<Result<List<String>>> getDistinctCropTypes({String? userId});
}
