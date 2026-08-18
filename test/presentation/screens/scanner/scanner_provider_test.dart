import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/image_quality_analyzer.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/usecases/scanner/scan_crop_usecase.dart';
import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/presentation/screens/scanner/scanner_provider.dart';

import 'package:cropguard_flutter/domain/repositories/i_classifier_repository.dart';

class _MockScanCropUseCase extends Mock implements ScanCropUseCase {}
class _MockAuthRepo extends Mock implements IAuthRepository {}
class _MockAnalyticsService extends Mock implements AnalyticsService {}
class _MockClassifierRepo extends Mock implements IClassifierRepository {}

const _kDetection = DetectionResult(
  id: 123,
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

void main() {
  late _MockScanCropUseCase mockScanCropUseCase;
  late _MockAuthRepo mockAuthRepo;
  late _MockAnalyticsService mockAnalytics;
  late _MockClassifierRepo mockClassifierRepo;
  late ScannerProvider provider;

  setUp(() {
    mockScanCropUseCase = _MockScanCropUseCase();
    mockAuthRepo = _MockAuthRepo();
    mockAnalytics = _MockAnalyticsService();
    mockClassifierRepo = _MockClassifierRepo();

    when(() => mockAuthRepo.currentUser).thenReturn(
      AppUser(id: 'user_1', email: 'test@e.com', displayName: 'Farmer', isAnonymous: false),
    );
    when(() => mockAnalytics.logScanStarted(source: any(named: 'source'))).thenAnswer((_) async {});
    when(() => mockAnalytics.logScanCompleted(
      disease: any(named: 'disease'),
      confidence: any(named: 'confidence'),
      isHealthy: any(named: 'isHealthy'),
    )).thenAnswer((_) async {});
    when(() => mockAnalytics.logScanFailed(reason: any(named: 'reason'))).thenAnswer((_) async {});

    provider = ScannerProvider(mockScanCropUseCase, mockAuthRepo, mockAnalytics, mockClassifierRepo);
  });

  group('ScannerProvider - Batch Mode', () {
    test('setBatchMode toggles the state and clears image paths', () {
      provider.addCapturedToBatch('path/1.jpg');
      expect(provider.batchImagePaths, contains('path/1.jpg'));

      provider.setBatchMode(true);
      expect(provider.batchMode, isTrue);
      expect(provider.batchImagePaths, isEmpty);
    });

    test('addCapturedToBatch appends to path list', () {
      provider.addCapturedToBatch('path/2.jpg');
      expect(provider.batchImagePaths, contains('path/2.jpg'));
    });

    test('analyseBatch runs usecase on all paths and returns results', () async {
      provider.addCapturedToBatch('path/1.jpg');
      provider.addCapturedToBatch('path/2.jpg');

      when(() => mockScanCropUseCase(any(), any()))
          .thenAnswer((_) async => Result.success(_kDetection));

      final results = await provider.analyseBatch();

      expect(results, hasLength(2));
      expect(provider.batchMode, isFalse);
      expect(provider.batchImagePaths, isEmpty);
    });
  });

  group('ScannerProvider - Single Scan', () {
    test('analyseAndSave returns detection result on success', () async {
      when(() => mockScanCropUseCase(any(), any()))
          .thenAnswer((_) async => Result.success(_kDetection));

      final res = await provider.analyseAndSave('path/to/img.jpg');

      expect(res, isNotNull);
      expect(res!.id, 123);
      expect(provider.errorMessage, isNull);
    });

    test('analyseAndSave sets errorMessage on quality failure', () async {
      when(() => mockScanCropUseCase(any(), any()))
          .thenAnswer((_) async => Result.error(QualityFailure(ImageQualityIssue.blurry, 'Blurry image')));

      final res = await provider.analyseAndSave('path/to/img.jpg');

      expect(res, isNull);
      expect(provider.errorMessage, contains('too blurry'));
    });

    test('analyseAndSave sets errorMessage on general failure', () async {
      when(() => mockScanCropUseCase(any(), any()))
          .thenAnswer((_) async => Result.error(MLFailure('Inference error')));

      final res = await provider.analyseAndSave('path/to/img.jpg');

      expect(res, isNull);
      expect(provider.errorMessage, 'Inference error');
    });
  });
}
