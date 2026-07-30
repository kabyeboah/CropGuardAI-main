import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/models/field.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/repositories/detection_repository_impl.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

const _kDetection = DetectionResult(
  id: 1,
  userId: 'user_1',
  imagePath: 'path/to/img.jpg',
  diseaseLabel: 'Apple___healthy',
  displayName: 'Healthy Apple',
  confidence: 0.99,
  isHealthy: true,
  cropType: 'Apple',
  cause: '',
  treatments: [],
  timestamp: 1234567,
);

const _kField = Field(
  id: 'f1',
  name: 'North',
  cropType: 'Maize',
  sizeHectares: 2.0,
);

void main() {
  late _MockDatabaseHelper mockDb;
  late DetectionRepositoryImpl repository;

  setUp(() {
    mockDb = _MockDatabaseHelper();
    repository = DetectionRepositoryImpl(mockDb);
    registerFallbackValue(_kDetection);
    registerFallbackValue(_kField);
  });

  group('DetectionRepositoryImpl - save & delete', () {
    test('saveDetection returns success with ID', () async {
      when(() => mockDb.insertDetection(any())).thenAnswer((_) async => 42);

      final res = await repository.saveDetection(_kDetection);

      expect(res.isSuccess, isTrue);
      expect(res.data, 42);
      verify(() => mockDb.insertDetection(_kDetection)).called(1);
    });

    test('saveDetection returns error on cache/db failure', () async {
      when(() => mockDb.insertDetection(any())).thenThrow(Exception('DB Error'));

      final res = await repository.saveDetection(_kDetection);

      expect(res.isError, isTrue);
      expect(res.failure, isA<CacheFailure>());
      expect(res.failure!.message, contains('DB Error'));
    });

    test('deleteDetection returns success', () async {
      when(() => mockDb.deleteDetection(any())).thenAnswer((_) async {});

      final res = await repository.deleteDetection(42);

      expect(res.isSuccess, isTrue);
      verify(() => mockDb.deleteDetection(42)).called(1);
    });
  });

  group('DetectionRepositoryImpl - fields', () {
    test('saveField calls upsertField on database helper', () async {
      when(() => mockDb.upsertField(any())).thenAnswer((_) async {});

      final res = await repository.saveField(_kField);

      expect(res.isSuccess, isTrue);
      verify(() => mockDb.upsertField(_kField)).called(1);
    });

    test('getFields returns success with list', () async {
      when(() => mockDb.getFields(userId: any(named: 'userId'))).thenAnswer((_) async => [_kField]);

      final res = await repository.getFields(userId: 'u1');

      expect(res.isSuccess, isTrue);
      expect(res.data, contains(_kField));
    });
  });
}
