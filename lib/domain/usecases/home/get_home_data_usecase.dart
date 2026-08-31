import '../../../core/utils/result.dart';
import '../../models/detection_result.dart';
import '../../repositories/i_detection_repository.dart';

class HomeData {
  final Map<String, int> stats;
  final List<DetectionResult> recentScans;
  final List<Map<String, dynamic>> trend;

  HomeData({
    required this.stats,
    required this.recentScans,
    required this.trend,
  });
}

class GetHomeDataUseCase {
  final IDetectionRepository _repository;

  GetHomeDataUseCase(this._repository);

  Future<Result<HomeData>> call({String? userId}) async {
    final statsResult = await _repository.getFarmStats(userId: userId);
    final scansResult =
        await _repository.getRecentDetections(userId: userId, limit: 5);
    final trendResult =
        await _repository.getDailyTrend(days: 7, userId: userId);

    if (statsResult.isError) return Result.error(statsResult.failure!);
    if (scansResult.isError) return Result.error(scansResult.failure!);
    if (trendResult.isError) return Result.error(trendResult.failure!);

    return Result.success(HomeData(
      stats: statsResult.data ?? {'total': 0, 'healthy': 0, 'diseased': 0},
      recentScans: scansResult.data ?? [],
      trend: trendResult.data ?? [],
    ));
  }
}
