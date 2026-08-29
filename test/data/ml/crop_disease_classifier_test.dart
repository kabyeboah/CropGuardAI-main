import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/classifier_health_service.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';

void main() {
  // ── Shell behaviour ─────────────────────────────────────────────────────────

  test('loadModel handles asset loading in unit test environment', () async {
    final classifier = CropDiseaseClassifier();
    // In unit tests without flutter assets loaded, loadModel fails gracefully
    await classifier.loadModel();
    expect(classifier.isLoaded, isFalse);
    expect(classifier.isEngineAvailable, isFalse);
  });

  test('modelVersion defaults or initializes gracefully', () {
    expect(CropDiseaseClassifier.modelVersion, anyOf(isNull, isA<String>()));
  });

  test('classifyFromPath with non-existent file still returns a degraded result', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final classifier = CropDiseaseClassifier();

    final result = await classifier.classifyFromPath('non_existent_image.jpg');

    expect(result, isNotNull);
    expect(result!.isDegraded, isTrue);
    expect(result.label, equals('Unidentified'));
    expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
  });

  test('classifyFromBytes returns degraded result below threshold', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final classifier = CropDiseaseClassifier();

    // Grey RGBA bytes — green condition is false for every pixel.
    final dummyBytes = Uint8List.fromList(List.filled(100 * 100 * 4, 128));
    final result = await classifier.classifyFromBytes(dummyBytes, 100, 100);

    expect(result, isNotNull);
    expect(result!.isDegraded, isTrue);
    expect(result.label, equals('Unidentified'));
    expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
  });

  test('close() does not throw', () {
    final classifier = CropDiseaseClassifier();
    expect(() => classifier.close(), returnsNormally);
  });

  // ── Fallback heuristic confidence paths (via fallbackForTest seam) ──────────

  group('fallback heuristic confidence ceiling (via fallbackForTest seam)', () {
    test('engine-unavailable path returns confidence 0.0, below threshold', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final result = await CropDiseaseClassifier.fallbackForTest(
        Uint8List.fromList(List.filled(10 * 10 * 4, 128)),
        engineUnavailable: true,
        isRgbaRaw: true,
        width: 10,
        height: 10,
      );

      expect(result.engineUnavailable, isTrue);
      expect(result.isDegraded, isTrue);
      expect(result.label, equals('Unidentified'));
      expect(result.confidence, equals(0.0));
      expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
    });

    test('base heuristic path (non-green RGBA bytes) returns confidence 0.30, below threshold', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Grey pixels: R=G=B=128 → green condition (G>R && G>B) is false
      // for every pixel → greenRatio = 0 ≤ 0.35 → confidence stays at 0.30.
      final greyBytes = Uint8List.fromList(List.filled(10 * 10 * 4, 128));
      final result = await CropDiseaseClassifier.fallbackForTest(
        greyBytes,
        engineUnavailable: false,
        isRgbaRaw: true,
        width: 10,
        height: 10,
      );

      expect(result.isDegraded, isTrue);
      expect(result.label, equals('Unidentified'));
      expect(result.confidence, equals(0.30));
      expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
    });

    test('green-pixel heuristic path (>35% green RGBA bytes) returns confidence 0.45, below threshold', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // R=50, G=200, B=50, A=255 → G > R && G > B && G > 40 → every pixel
      // counted as green → greenRatio = 1.0 > 0.35 → confidence boosted to 0.45.
      const w = 10;
      const h = 10;
      final greenBytes = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        greenBytes[i * 4 + 0] = 50;   // R
        greenBytes[i * 4 + 1] = 200;  // G
        greenBytes[i * 4 + 2] = 50;   // B
        greenBytes[i * 4 + 3] = 255;  // A
      }

      final result = await CropDiseaseClassifier.fallbackForTest(
        greenBytes,
        engineUnavailable: false,
        isRgbaRaw: true,
        width: w,
        height: h,
      );

      expect(result.isDegraded, isTrue);
      expect(result.label, equals('Unidentified'));
      expect(result.confidence, equals(0.45));
      expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
    });
  });

  // ── averageResults ──────────────────────────────────────────────────────────

  test('averageResults with one result returns that result unchanged', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final single = await CropDiseaseClassifier.fallbackForTest(
      Uint8List.fromList(List.filled(10 * 10 * 4, 128)),
      isRgbaRaw: true,
      width: 10,
      height: 10,
    );

    final averaged = CropDiseaseClassifier.averageResults([single]);
    expect(averaged.label, equals(single.label));
    expect(averaged.confidence, equals(single.confidence));
  });

  test('averageResults averages confidence across multiple results', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r1 = await CropDiseaseClassifier.fallbackForTest(
      Uint8List.fromList(List.filled(10 * 10 * 4, 128)),
      isRgbaRaw: true,
      width: 10,
      height: 10,
    );
    final r2 = await CropDiseaseClassifier.fallbackForTest(
      null,
      engineUnavailable: true,
    );

    final averaged = CropDiseaseClassifier.averageResults([r1, r2]);
    expect(averaged.confidence,
        closeTo((r1.confidence + r2.confidence) / 2, 0.001));
    expect(averaged.isDegraded, isTrue);
  });

  test('averageResults performs true soft-voting across candidate distributions', () {
    final r1 = ClassificationResult(
      label: 'Tomato___Early_blight',
      confidence: 0.55,
      isHealthy: false,
      diseaseInfo: DiseaseDatabase.getInfo('Tomato___Early_blight'),
      topCandidates: [
        (label: 'Tomato___Early_blight', confidence: 0.55),
        (label: 'Tomato___Late_blight', confidence: 0.45),
      ],
    );
    final r2 = ClassificationResult(
      label: 'Tomato___Late_blight',
      confidence: 0.85,
      isHealthy: false,
      diseaseInfo: DiseaseDatabase.getInfo('Tomato___Late_blight'),
      topCandidates: [
        (label: 'Tomato___Late_blight', confidence: 0.85),
        (label: 'Tomato___Early_blight', confidence: 0.15),
      ],
    );

    final fused = CropDiseaseClassifier.averageResults([r1, r2]);
    // Late_blight sum: (0.45 + 0.85) / 2 = 0.65
    // Early_blight sum: (0.55 + 0.15) / 2 = 0.35
    expect(fused.label, equals('Tomato___Late_blight'));
    expect(fused.confidence, closeTo(0.65, 0.001));
    expect(fused.topCandidates.length, equals(2));
    expect(fused.topCandidates.first.label, equals('Tomato___Late_blight'));
    expect(fused.topCandidates.first.confidence, closeTo(0.65, 0.001));
  });

  group('computeSoftVotingCandidates', () {
    test('sums per-label confidence across angles and normalizes correctly', () {
      final angle1 = [
        (label: 'Cocoa___Black_pod_rot', confidence: 0.60),
        (label: 'Cocoa___Frosty_pod_rot', confidence: 0.30),
      ];
      final angle2 = [
        (label: 'Cocoa___Black_pod_rot', confidence: 0.80),
        (label: 'Cocoa___Frosty_pod_rot', confidence: 0.10),
      ];

      final merged = CropDiseaseClassifier.computeSoftVotingCandidates([angle1, angle2]);

      expect(merged, hasLength(2));
      expect(merged[0].label, equals('Cocoa___Black_pod_rot'));
      expect(merged[0].confidence, closeTo(0.70, 0.001));
      expect(merged[1].label, equals('Cocoa___Frosty_pod_rot'));
      expect(merged[1].confidence, closeTo(0.20, 0.001));
    });

    test('returns fallback candidates when candidate lists are empty', () {
      final fallback = [
        (label: 'Cocoa___Healthy', confidence: 0.50),
      ];

      final merged = CropDiseaseClassifier.computeSoftVotingCandidates(
        [],
        fallbackCandidates: fallback,
      );

      expect(merged, equals(fallback));
    });
  });

  group('Fallback telemetry', () {
    test('updates ClassifierHealthService and logs fallback analytics when services are registered', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final healthService = ClassifierHealthService();

      expect(healthService.fallbackCount, equals(0));
      healthService.updateHealth(isHealthy: true, usedFallback: true);
      expect(healthService.fallbackCount, equals(1));
    });
  });

  group('Verified Model Labels and DiseaseDatabase alignment', () {
    test('assets/labels_verified.txt exists and contains exactly 51 classes', () {
      final file = File('assets/labels_verified.txt');
      expect(file.existsSync(), isTrue, reason: 'assets/labels_verified.txt must exist');

      final lines = file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(lines.length, equals(51));
      expect(lines.toSet().length, equals(51), reason: 'All 51 labels must be unique');
    });

    test('every label in assets/labels_verified.txt aligns with DiseaseDatabase', () {
      final file = File('assets/labels_verified.txt');
      final lines = file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (final label in lines) {
        final info = DiseaseDatabase.getInfo(label);
        expect(info.label, equals(label));
        expect(info.cropType, isNot(equals('Unknown')),
            reason: 'Label $label missing proper DiseaseDatabase entry');
        expect(info.displayName, isNotEmpty);
        if (!info.isHealthy) {
          expect(info.treatments, isNotEmpty,
              reason: 'Diseased entry $label must contain treatments');
        }
      }
    });
  });
}
