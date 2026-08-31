import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/usecases/history/get_history_usecase.dart';

class MockDetectionRepository extends Mock implements IDetectionRepository {}

void main() {
  late GetHistoryUseCase useCase;
  late MockDetectionRepository mockRepository;

  DetectionResult makeResult(int id) => DetectionResult(
        id: id,
        userId: 'user_1',
        imagePath: '/tmp/$id.jpg',
        diseaseLabel: 'Tomato___Early_blight',
        displayName: 'Early Blight',
        confidence: 0.9,
        isHealthy: false,
        cropType: 'Tomato',
        cause: 'Fungal infection',
        treatments: ['Remove infected leaves'],
        timestamp: 1000 * id,
      );

  setUp(() {
    mockRepository = MockDetectionRepository();
    useCase = GetHistoryUseCase(mockRepository);
  });

  group('GetHistoryUseCase', () {
    test('returns list of detections for a given userId', () async {
      final scans = [makeResult(1), makeResult(2)];
      when(() => mockRepository.getHistory(
            userId: 'user_1',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            isHealthy: any(named: 'isHealthy'),
            cropTypes: any(named: 'cropTypes'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            searchQuery: any(named: 'searchQuery'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => Result.success(scans));

      final result = await useCase(userId: 'user_1');

      expect(result.isSuccess, true);
      expect(result.data, scans);
    });

    test('returns empty list when user has no history', () async {
      when(() => mockRepository.getHistory(
            userId: any(named: 'userId'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            isHealthy: any(named: 'isHealthy'),
            cropTypes: any(named: 'cropTypes'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            searchQuery: any(named: 'searchQuery'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => Result.success([]));

      final result = await useCase(userId: 'new_user');

      expect(result.isSuccess, true);
      expect(result.data, isEmpty);
    });

    test('calls repository without userId when none provided', () async {
      when(() => mockRepository.getHistory(
            userId: any(named: 'userId'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            isHealthy: any(named: 'isHealthy'),
            cropTypes: any(named: 'cropTypes'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            searchQuery: any(named: 'searchQuery'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => Result.success([]));

      await useCase();

      verify(() => mockRepository.getHistory(
            userId: any(named: 'userId'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            isHealthy: any(named: 'isHealthy'),
            cropTypes: any(named: 'cropTypes'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            searchQuery: any(named: 'searchQuery'),
            orderBy: any(named: 'orderBy'),
          )).called(1);
    });

    test('returns failure when repository fails', () async {
      when(() => mockRepository.getHistory(
                userId: any(named: 'userId'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                isHealthy: any(named: 'isHealthy'),
                cropTypes: any(named: 'cropTypes'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
                searchQuery: any(named: 'searchQuery'),
                orderBy: any(named: 'orderBy'),
              ))
          .thenAnswer(
              (_) async => Result.error(const CacheFailure('database error')));

      final result = await useCase(userId: 'user_1');

      expect(result.isError, true);
      expect(result.failure, isA<CacheFailure>());
    });
  });
}
