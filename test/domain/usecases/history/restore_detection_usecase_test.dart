import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/usecases/history/restore_detection_usecase.dart';

class _MockDetectionRepo extends Mock implements IDetectionRepository {}

// Minimal DetectionResult for testing
const _kDetection = DetectionResult(
  id: 42,
  userId: 'u1',
  imagePath: '/img/test.jpg',
  diseaseLabel: 'Apple___healthy',
  displayName: 'Healthy Apple',
  confidence: 0.95,
  severity: 'healthy',
  isHealthy: true,
  cropType: 'Apple',
  cause: '',
  treatments: ['Keep watering'],
  timestamp: 1_000_000,
);

void main() {
  late _MockDetectionRepo repo;
  late RestoreDetectionUseCase useCase;

  setUp(() {
    repo = _MockDetectionRepo();
    useCase = RestoreDetectionUseCase(repo);
    registerFallbackValue(_kDetection);
  });

  group('RestoreDetectionUseCase', () {
    test('calls saveDetection with the provided DetectionResult', () async {
      when(() => repo.saveDetection(any()))
          .thenAnswer((_) async => Result.success(99));

      await useCase(_kDetection);

      verify(() => repo.saveDetection(_kDetection)).called(1);
    });

    test('returns the new id on success', () async {
      when(() => repo.saveDetection(any()))
          .thenAnswer((_) async => Result.success(99));

      final result = await useCase(_kDetection);

      expect(result.isSuccess, isTrue);
      expect(result.data, 99);
    });

    test('propagates repository failure', () async {
      when(() => repo.saveDetection(any()))
          .thenAnswer((_) async => Result.error(CacheFailure('DB write failed')));

      final result = await useCase(_kDetection);

      expect(result.isError, isTrue);
      expect(result.failure, isA<CacheFailure>());
    });
  });
}
