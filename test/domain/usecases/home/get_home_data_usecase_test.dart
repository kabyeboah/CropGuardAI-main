import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/usecases/home/get_home_data_usecase.dart';

class _MockDetectionRepo extends Mock implements IDetectionRepository {}

void main() {
  late _MockDetectionRepo repo;
  late GetHomeDataUseCase useCase;

  setUp(() {
    repo = _MockDetectionRepo();
    useCase = GetHomeDataUseCase(repo);
  });

  final stats = {'total': 10, 'healthy': 7, 'diseased': 3};
  final scans = <DetectionResult>[];
  final trend = <Map<String, dynamic>>[];

  group('GetHomeDataUseCase', () {
    test('returns HomeData when all three repo calls succeed', () async {
      when(() => repo.getFarmStats(userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success(stats));
      when(() => repo.getRecentDetections(userId: any(named: 'userId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Result.success(scans));
      when(() => repo.getDailyTrend(days: any(named: 'days'), userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success(trend));

      final result = await useCase(userId: 'u1');

      expect(result.isSuccess, isTrue);
      expect(result.data!.stats, stats);
      expect(result.data!.recentScans, isEmpty);
    });

    test('returns error when getFarmStats fails', () async {
      when(() => repo.getFarmStats(userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.error(const CacheFailure('stats fail')));
      when(() => repo.getRecentDetections(userId: any(named: 'userId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Result.success(scans));
      when(() => repo.getDailyTrend(days: any(named: 'days'), userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success(trend));

      final result = await useCase();

      expect(result.isError, isTrue);
      expect(result.failure?.message, 'stats fail');
    });

    test('returns error when getRecentDetections fails', () async {
      when(() => repo.getFarmStats(userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success(stats));
      when(() => repo.getRecentDetections(userId: any(named: 'userId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Result.error(const CacheFailure('scans fail')));
      when(() => repo.getDailyTrend(days: any(named: 'days'), userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success(trend));

      final result = await useCase();

      expect(result.isError, isTrue);
      expect(result.failure?.message, 'scans fail');
    });

    test('returns error when getDailyTrend fails', () async {
      when(() => repo.getFarmStats(userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success(stats));
      when(() => repo.getRecentDetections(userId: any(named: 'userId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Result.success(scans));
      when(() => repo.getDailyTrend(days: any(named: 'days'), userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.error(const CacheFailure('trend fail')));

      final result = await useCase();

      expect(result.isError, isTrue);
      expect(result.failure?.message, 'trend fail');
    });

    test('uses default empty values when repo returns null data', () async {
      when(() => repo.getFarmStats(userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success({'total': 0, 'healthy': 0, 'diseased': 0}));
      when(() => repo.getRecentDetections(userId: any(named: 'userId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Result.success([]));
      when(() => repo.getDailyTrend(days: any(named: 'days'), userId: any(named: 'userId')))
          .thenAnswer((_) async => Result.success([]));

      final result = await useCase();

      expect(result.isSuccess, isTrue);
      expect(result.data!.recentScans, isEmpty);
      expect(result.data!.trend, isEmpty);
    });
  });
}
