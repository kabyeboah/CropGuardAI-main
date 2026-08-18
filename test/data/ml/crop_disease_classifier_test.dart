import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';

void main() {
  test('verify labels.txt alignment with DiseaseDatabase', () {
    final file = File('assets/labels.txt');
    expect(file.existsSync(), isTrue, reason: 'assets/labels.txt must exist');

    final lines = file
        .readAsStringSync()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    expect(lines.length, equals(93), reason: 'V1 model should have exactly 93 classes');

    for (final label in lines) {
      final info = DiseaseDatabase.getInfo(label);
      expect(
        info.cropType,
        isNot(equals('Unknown')),
        reason: 'Label "$label" in assets/labels.txt is missing from DiseaseDatabase or has Unknown cropType.',
      );
    }
  });

  test('verify labels_v2.txt alignment with DiseaseDatabase', () {
    final file = File('assets/labels_v2.txt');
    expect(file.existsSync(), isTrue, reason: 'assets/labels_v2.txt must exist');

    final lines = file
        .readAsStringSync()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    expect(lines.length, equals(16), reason: 'V2 model should have exactly 16 classes');

    for (final label in lines) {
      final info = DiseaseDatabase.getInfo(label);
      expect(
        info.cropType,
        isNot(equals('Unknown')),
        reason: 'Label "$label" in assets/labels_v2.txt is missing from DiseaseDatabase or has Unknown cropType.',
      );
    }
  });

  test('CropDiseaseClassifier initial state and engineUnavailable fallback behavior', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final classifier = CropDiseaseClassifier();

    expect(classifier.isLoaded, isFalse);
    expect(classifier.isEngineAvailable, isTrue);

    // Running classification in plain unit test environment triggers stage failure, setting engineUnavailable
    final result = await classifier.classifyFromPath('non_existent_image.jpg');
    expect(result, isNotNull);
    expect(classifier.isLoaded, isFalse);
    expect(classifier.isEngineAvailable, isFalse);
    expect(result!.engineUnavailable, isTrue);
    expect(result.isDegraded, isTrue);
    expect(result.confidence, equals(0.0));
    expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
    expect(result.label, equals('Unidentified'));
  });

  // NOTE: In a unit-test environment loadModel() always fails (no TFLite assets),
  // which marks _engineAvailable = false before the fallback is called. That means
  // classifyFromBytes will always produce engineUnavailable = true and confidence = 0.0
  // — identical to the engine-unavailable path above.
  // The 0.30 / 0.45 heuristic branches are tested directly below via
  // CropDiseaseClassifier.fallbackForTest(), which bypasses loadModel entirely.
  test('classifyFromBytes fallback returns confidence below threshold and Unidentified label', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final classifier = CropDiseaseClassifier();

    // Grey RGBA bytes: R=G=B=128, so the green-pixel condition (G>R && G>B) is
    // false for every pixel. loadModel fails in unit-test context, so
    // engineUnavailable ends up true and confidence == 0.0.
    final dummyBytes = Uint8List.fromList(List.filled(100 * 100 * 4, 128));
    final result = await classifier.classifyFromBytes(dummyBytes, 100, 100);

    expect(result, isNotNull);
    expect(result!.isDegraded, isTrue);
    expect(result.label, equals('Unidentified'));
    expect(result.confidence, lessThan(CropDiseaseClassifier.confidenceThreshold));
  });

  group('fallback heuristic confidence ceiling (via fallbackForTest seam)', () {
    // These tests use CropDiseaseClassifier.fallbackForTest to call
    // _fallbackVisualClassification directly with a controlled engineUnavailable
    // flag, making the 0.30 and 0.45 branches deterministically reachable without
    // requiring TFLite assets or a real image file.

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

      // Grey pixels: R=G=B=128 → green-pixel condition (G>R && G>B) is false
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

      // Build a 10×10 RGBA buffer where every pixel is dominantly green:
      // R=50, G=200, B=50, A=255 → G > R && G > B && G > 40 → all 100 pixels
      // counted as green → greenRatio = 1.0 > 0.35 → confidence boosted to 0.45.
      const w = 10;
      const h = 10;
      final greenBytes = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        greenBytes[i * 4 + 0] = 50;  // R
        greenBytes[i * 4 + 1] = 200; // G
        greenBytes[i * 4 + 2] = 50;  // B
        greenBytes[i * 4 + 3] = 255; // A
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
}
