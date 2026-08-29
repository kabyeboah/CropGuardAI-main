import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/usecases/history/delete_detection_usecase.dart';

class MockDetectionRepository extends Mock implements IDetectionRepository {}

void main() {
  late DeleteDetectionUseCase useCase;
  late MockDetectionRepository mockRepository;

  setUp(() {
    mockRepository = MockDetectionRepository();
    useCase = DeleteDetectionUseCase(mockRepository);
  });

  group('DeleteDetectionUseCase', () {
    test('returns success when deletion succeeds', () async {
      when(() => mockRepository.deleteDetection(42))
          .thenAnswer((_) async => Result.success(null));

      final result = await useCase(42);

      expect(result.isSuccess, true);
      verify(() => mockRepository.deleteDetection(42)).called(1);
    });

    test('passes the correct id to the repository', () async {
      when(() => mockRepository.deleteDetection(any()))
          .thenAnswer((_) async => Result.success(null));

      await useCase(99);

      verify(() => mockRepository.deleteDetection(99)).called(1);
    });

    test('returns failure when repository fails', () async {
      when(() => mockRepository.deleteDetection(any())).thenAnswer(
          (_) async => Result.error(const CacheFailure('file not found')));

      final result = await useCase(1);

      expect(result.isError, true);
      expect(result.failure!.message, 'file not found');
    });

    test('does not call any other repository method', () async {
      when(() => mockRepository.deleteDetection(any()))
          .thenAnswer((_) async => Result.success(null));

      await useCase(5);

      verify(() => mockRepository.deleteDetection(5)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
