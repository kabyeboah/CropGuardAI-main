import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';

void main() {
  // ── Shell & Exception behaviour ─────────────────────────────────────────────

  test(
      'loadModel handles asset loading failure by throwing explicit MLException',
      () async {
    final classifier = CropDiseaseClassifier();
    await expectLater(classifier.loadModel(), throwsA(isA<MLException>()));
    expect(classifier.isLoaded, isFalse);
    expect(classifier.isEngineAvailable, isFalse);
  });

  test('modelVersion defaults or initializes gracefully', () {
    expect(CropDiseaseClassifier.modelVersion, anyOf(isNull, isA<String>()));
  });

  test('classifyFromPath with non-existent file throws ModelInputException',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final classifier = CropDiseaseClassifier();

    await expectLater(
      classifier.classifyFromPath('non_existent_image.jpg'),
      throwsA(isA<ModelInputException>()
          .having((e) => e.code, 'code', 'MODEL_INPUT_INVALID')),
    );
  });

  test('classifyFromBytes with invalid dimensions throws ModelInputException',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final classifier = CropDiseaseClassifier();

    final dummyBytes = Uint8List(0);
    await expectLater(
      classifier.classifyFromBytes(dummyBytes, 0, 0),
      throwsA(isA<ModelInputException>()
          .having((e) => e.code, 'code', 'MODEL_INPUT_INVALID')),
    );
  });

  test('close() closes interpreter and resets loaded state without throwing',
      () {
    final classifier = CropDiseaseClassifier();
    expect(() => classifier.close(), returnsNormally);
    expect(classifier.isLoaded, isFalse);
  });

  // ── Explicit ML Exceptions ───────────────────────────────────────────────────

  group('Explicit ML Exceptions and failure codes', () {
    test('ModelLoadException has code MODEL_LOAD_FAILED', () {
      const e = ModelLoadException('Asset not found');
      expect(e.code, equals('MODEL_LOAD_FAILED'));
      expect(e.toString(), contains('MODEL_LOAD_FAILED'));
    });

    test('ModelContractException has code MODEL_CONTRACT_FAILED', () {
      const e = ModelContractException('Shape mismatch');
      expect(e.code, equals('MODEL_CONTRACT_FAILED'));
      expect(e.toString(), contains('MODEL_CONTRACT_FAILED'));
    });

    test('ModelInputException has code MODEL_INPUT_INVALID', () {
      const e = ModelInputException('Decode error');
      expect(e.code, equals('MODEL_INPUT_INVALID'));
      expect(e.toString(), contains('MODEL_INPUT_INVALID'));
    });

    test('ModelInferenceException has code MODEL_INFERENCE_FAILED', () {
      const e = ModelInferenceException('Runtime error');
      expect(e.code, equals('MODEL_INFERENCE_FAILED'));
      expect(e.toString(), contains('MODEL_INFERENCE_FAILED'));
    });

    test('LabelContractException has code LABEL_CONTRACT_FAILED', () {
      const e = LabelContractException('Count mismatch');
      expect(e.code, equals('LABEL_CONTRACT_FAILED'));
      expect(e.toString(), contains('LABEL_CONTRACT_FAILED'));
    });
  });

  // ── averageResults ──────────────────────────────────────────────────────────

  test('averageResults with one result returns that result unchanged', () {
    final single = ClassificationResult(
      label: 'Tomato___Early_blight',
      confidence: 0.85,
      isHealthy: false,
      diseaseInfo: DiseaseDatabase.getInfo('Tomato___Early_blight'),
      topCandidates: [(label: 'Tomato___Early_blight', confidence: 0.85)],
    );

    final averaged = CropDiseaseClassifier.averageResults([single]);
    expect(averaged.label, equals(single.label));
    expect(averaged.confidence, equals(single.confidence));
  });

  test('averageResults averages confidence across multiple results', () {
    final r1 = ClassificationResult(
      label: 'Tomato___Early_blight',
      confidence: 0.40,
      isHealthy: false,
      diseaseInfo: DiseaseDatabase.getInfo('Tomato___Early_blight'),
      isDegraded: true,
      topCandidates: [(label: 'Tomato___Early_blight', confidence: 0.40)],
    );
    final r2 = ClassificationResult(
      label: 'Tomato___Early_blight',
      confidence: 0.80,
      isHealthy: false,
      diseaseInfo: DiseaseDatabase.getInfo('Tomato___Early_blight'),
      topCandidates: [(label: 'Tomato___Early_blight', confidence: 0.80)],
    );

    final averaged = CropDiseaseClassifier.averageResults([r1, r2]);
    expect(averaged.confidence, closeTo(0.60, 0.001));
    expect(averaged.isDegraded, isTrue);
  });

  test(
      'averageResults performs true soft-voting across candidate distributions',
      () {
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
    test('sums per-label confidence across angles and normalizes correctly',
        () {
      final angle1 = [
        (label: 'Cashew___Red_Rust', confidence: 0.60),
        (label: 'Cashew___Gumosis', confidence: 0.30),
      ];
      final angle2 = [
        (label: 'Cashew___Red_Rust', confidence: 0.80),
        (label: 'Cashew___Gumosis', confidence: 0.10),
      ];

      final merged =
          CropDiseaseClassifier.computeSoftVotingCandidates([angle1, angle2]);

      expect(merged, hasLength(2));
      expect(merged[0].label, equals('Cashew___Red_Rust'));
      expect(merged[0].confidence, closeTo(0.70, 0.001));
      expect(merged[1].label, equals('Cashew___Gumosis'));
      expect(merged[1].confidence, closeTo(0.20, 0.001));
    });

    test(
        'returns empty candidates when candidate lists are empty without synthesizing fake labels',
        () {
      final merged = CropDiseaseClassifier.computeSoftVotingCandidates([]);
      expect(merged, isEmpty);
    });
  });

  group('Canonical Model Contract and DiseaseDatabase alignment', () {
    test('assets/model_metadata.json exists and strictly specifies contract',
        () {
      final file = File('assets/model_metadata.json');
      expect(file.existsSync(), isTrue,
          reason: 'assets/model_metadata.json must exist');

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['model_file'], equals('cropguard_plant_disease.tflite'));
      expect(json['labels_file'], equals('labels.txt'));
      expect(json['input_size'], equals(128));
      expect(json['num_classes'], equals(51));
      expect(json['input_channels'], equals(3));
      expect(json['calibration_temperature'], isNotNull);
    });

    test('assets/labels.txt exists and contains exactly 51 unique classes', () {
      final file = File('assets/labels.txt');
      expect(file.existsSync(), isTrue, reason: 'assets/labels.txt must exist');

      final lines = file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(lines.length, equals(51));
      expect(lines.toSet().length, equals(51),
          reason: 'All 51 labels must be unique');
    });

    test('assets/cropguard_plant_disease.tflite exists', () {
      final file = File('assets/cropguard_plant_disease.tflite');
      expect(file.existsSync(), isTrue,
          reason: 'assets/cropguard_plant_disease.tflite must exist');
      expect(file.lengthSync(), greaterThan(100000));
    });

    test('every label in assets/labels.txt aligns with DiseaseDatabase', () {
      final file = File('assets/labels.txt');
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
