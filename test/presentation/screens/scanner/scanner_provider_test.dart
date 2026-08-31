import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/image_quality_analyzer.dart';
import 'package:cropguard_flutter/core/utils/safe_image_downloader.dart';
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
      AppUser(
          id: 'user_1',
          email: 'test@e.com',
          displayName: 'Farmer',
          isAnonymous: false),
    );
    when(() => mockAnalytics.logScanStarted(source: any(named: 'source')))
        .thenAnswer((_) async {});
    when(() => mockAnalytics.logScanCompleted(
          disease: any(named: 'disease'),
          confidence: any(named: 'confidence'),
          isHealthy: any(named: 'isHealthy'),
        )).thenAnswer((_) async {});
    when(() => mockAnalytics.logScanFailed(reason: any(named: 'reason')))
        .thenAnswer((_) async {});

    provider = ScannerProvider(
        mockScanCropUseCase, mockAuthRepo, mockAnalytics, mockClassifierRepo);
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

    test('analyseBatch runs usecase on all paths and returns results',
        () async {
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

    test(
        'analyseAndSave sets errorMessage and errorMessageCode on quality failure',
        () async {
      when(() => mockScanCropUseCase(any(), any())).thenAnswer((_) async =>
          Result.error(
              const QualityFailure(ImageQualityIssue.blurry, 'Blurry image')));

      final res = await provider.analyseAndSave('path/to/img.jpg');

      expect(res, isNull);
      expect(provider.errorMessage, contains('too blurry'));
      expect(provider.errorMessageCode, isNotNull);
      expect(provider.errorCode, isNotNull);
    });

    test(
        'analyseAndSave sets errorMessage and errorMessageCode on general failure',
        () async {
      when(() => mockScanCropUseCase(any(), any())).thenAnswer(
          (_) async => Result.error(const MLFailure('Inference error')));

      final res = await provider.analyseAndSave('path/to/img.jpg');

      expect(res, isNull);
      expect(provider.errorMessage, 'Inference error');
      expect(provider.errorMessageCode, isNotNull);
    });

    test('analyseAndSave handles uncaught exception without leaking raw text',
        () async {
      when(() => mockScanCropUseCase(any(), any()))
          .thenThrow(Exception('platform crash 0xdeadbeef'));

      final res = await provider.analyseAndSave('path/to/img.jpg');

      expect(res, isNull);
      expect(provider.errorMessage, 'Analysis failed');
      expect(provider.errorMessage, isNot(contains('0xdeadbeef')));
      expect(provider.errorMessageCode, isNotNull);
    });
  });

  group('ScannerProvider - Merged Scan Saving', () {
    test(
        'saveMergedScan delegates to saveResolvedScan and returns saved detection',
        () async {
      when(() => mockScanCropUseCase.saveResolvedScan(
            imagePath: any(named: 'imagePath'),
            userId: any(named: 'userId'),
            diseaseLabel: any(named: 'diseaseLabel'),
            confidence: any(named: 'confidence'),
            topCandidates: any(named: 'topCandidates'),
            isDegraded: any(named: 'isDegraded'),
          )).thenAnswer((_) async => Result.success(_kDetection));

      final res = await provider.saveMergedScan(
        imagePath: 'path/to/img.jpg',
        diseaseLabel: 'Apple___healthy',
        confidence: 0.95,
        topCandidates: [(label: 'Apple___healthy', confidence: 0.95)],
      );

      expect(res, isNotNull);
      expect(res!.id, 123);
      expect(provider.errorMessage, isNull);
      expect(provider.errorMessageCode, isNull);
    });

    test('saveMergedScan sets errorMessage on error', () async {
      when(() => mockScanCropUseCase.saveResolvedScan(
                imagePath: any(named: 'imagePath'),
                userId: any(named: 'userId'),
                diseaseLabel: any(named: 'diseaseLabel'),
                confidence: any(named: 'confidence'),
                topCandidates: any(named: 'topCandidates'),
                isDegraded: any(named: 'isDegraded'),
              ))
          .thenAnswer(
              (_) async => Result.error(const CacheFailure('Save failed')));

      final res = await provider.saveMergedScan(
        imagePath: 'path/to/img.jpg',
        diseaseLabel: 'Apple___healthy',
        confidence: 0.95,
        topCandidates: [(label: 'Apple___healthy', confidence: 0.95)],
      );

      expect(res, isNull);
      expect(provider.errorMessage, 'Save failed');
      expect(provider.errorMessageCode, isNotNull);
    });

    test('saveMergedScan handles uncaught exception without leaking raw text',
        () async {
      when(() => mockScanCropUseCase.saveResolvedScan(
            imagePath: any(named: 'imagePath'),
            userId: any(named: 'userId'),
            diseaseLabel: any(named: 'diseaseLabel'),
            confidence: any(named: 'confidence'),
            topCandidates: any(named: 'topCandidates'),
            isDegraded: any(named: 'isDegraded'),
          )).thenThrow(Exception('database lock error'));

      final res = await provider.saveMergedScan(
        imagePath: 'path/to/img.jpg',
        diseaseLabel: 'Apple___healthy',
        confidence: 0.95,
        topCandidates: [(label: 'Apple___healthy', confidence: 0.95)],
      );

      expect(res, isNull);
      expect(provider.errorMessage, 'Failed to save scan');
      expect(provider.errorMessage, isNot(contains('database lock error')));
      expect(provider.errorMessageCode, isNotNull);
    });
  });

  group('ScannerProvider - URL Image Download Safety', () {
    test('downloadFromUrl successfully downloads and updates capturedImagePath',
        () async {
      final mockDownloader = _MockSafeImageDownloader();
      final p = ScannerProvider(
        mockScanCropUseCase,
        mockAuthRepo,
        mockAnalytics,
        mockClassifierRepo,
        null,
        mockDownloader,
      );

      final dummyFile = File('/tmp/test_downloaded.jpg');
      when(() => mockDownloader.downloadImage(any()))
          .thenAnswer((_) async => dummyFile);

      final result = await p.downloadFromUrl('https://example.com/leaf.jpg');
      expect(result, dummyFile.path);
      expect(p.capturedImagePath, dummyFile.path);
      expect(p.errorMessage, isNull);
    });

    test(
        'downloadFromUrl sets security error message when SSRF/localhost is blocked',
        () async {
      final mockDownloader = _MockSafeImageDownloader();
      final p = ScannerProvider(
        mockScanCropUseCase,
        mockAuthRepo,
        mockAnalytics,
        mockClassifierRepo,
        null,
        mockDownloader,
      );

      when(() => mockDownloader.downloadImage(any()))
          .thenThrow(const ImageSecurityException('Localhost blocked'));

      final result = await p.downloadFromUrl('http://localhost/image.jpg');
      expect(result, isNull);
      expect(p.errorMessage, 'Localhost blocked');
      expect(p.errorMessageCode, isNotNull);
    });

    test('downloadFromUrl sets error on non-image response', () async {
      final mockDownloader = _MockSafeImageDownloader();
      final p = ScannerProvider(
        mockScanCropUseCase,
        mockAuthRepo,
        mockAnalytics,
        mockClassifierRepo,
        null,
        mockDownloader,
      );

      when(() => mockDownloader.downloadImage(any()))
          .thenThrow(const NonImageException('Response is not an image'));

      final result = await p.downloadFromUrl('https://example.com/page.html');
      expect(result, isNull);
      expect(p.errorMessage, 'Response is not an image');
      expect(p.errorMessageCode, isNotNull);
    });
  });
}

class _MockSafeImageDownloader extends Mock implements SafeImageDownloader {}
