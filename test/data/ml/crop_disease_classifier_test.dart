import 'dart:io';

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
  });
}
