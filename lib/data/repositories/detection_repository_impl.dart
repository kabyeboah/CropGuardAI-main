import '../../core/error/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/models/detection_result.dart';
import '../../domain/models/field.dart';
import '../../domain/repositories/i_detection_repository.dart';
import '../local/database_helper.dart';

class DetectionRepositoryImpl implements IDetectionRepository {
  final DatabaseHelper _dbHelper;

  DetectionRepositoryImpl(this._dbHelper);

  @override
  Future<Result<int>> saveDetection(DetectionResult result) async {
    try {
      final id = await _dbHelper.insertDetection(result);
      return Result.success(id);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final detections = await _dbHelper.getAllDetections(
        userId: userId,
        limit: limit,
        offset: offset,
        isHealthy: isHealthy,
        cropTypes: cropTypes,
        dateFrom: dateFrom,
        dateTo: dateTo,
        searchQuery: searchQuery,
        orderBy: orderBy,
        isSynced: isSynced,
      );
      return Result.success(detections);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<DetectionResult>>> getUnsyncedDetections({String? userId}) async {
    try {
      final detections = await _dbHelper.getUnsyncedDetections(userId: userId);
      return Result.success(detections);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> markDetectionSynced(int id, {int? syncedAt}) async {
    try {
      await _dbHelper.markDetectionSynced(id, syncedAt: syncedAt);
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> markDetectionsSynced(List<int> ids, {int? syncedAt}) async {
    try {
      await _dbHelper.markDetectionsSynced(ids, syncedAt: syncedAt);
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<DetectionResult?>> getDetection(int id) async {
    try {
      final detection = await _dbHelper.getDetectionById(id);
      return Result.success(detection);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<DetectionResult>>> getRecentDetections({String? userId, int limit = 5}) async {
    try {
      final detections = await _dbHelper.getRecentDetections(userId: userId, limit: limit);
      return Result.success(detections);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteDetection(int id) async {
    try {
      await _dbHelper.deleteDetection(id);
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> clearHistory() async {
    try {
      await _dbHelper.deleteAllDetections();
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, int>>> getFarmStats({String? userId}) async {
    try {
      final stats = await _dbHelper.getFarmStats(userId: userId);
      return Result.success(stats);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getDailyTrend({int days = 7, String? userId}) async {
    try {
      final trend = await _dbHelper.getDailyTrend(days: days, userId: userId);
      return Result.success(trend);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> saveField(Field field) async {
    try {
      await _dbHelper.upsertField(field);
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Field>>> getFields({String? userId}) async {
    try {
      final fields = await _dbHelper.getFields(userId: userId);
      return Result.success(fields);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteField(String id) async {
    try {
      await _dbHelper.deleteField(id);
      return Result.success(null);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<String>>> getDistinctCropTypes({String? userId}) async {
    try {
      final crops = await _dbHelper.getDistinctCropTypes(userId: userId);
      return Result.success(crops);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }
}
