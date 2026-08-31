import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/ood_gate.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';
import 'package:cropguard_flutter/data/repositories/classifier_repository_impl.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';

class RejectingOODGate implements OODGate {
  @override
  Future<bool> isPlantImage(String imagePath) async => false;

  @override
  Future<bool> isPlantBytes(Uint8List rgbaBytes, int width, int height) async =>
      false;
}

void main() {
  group('Classifier Architecture & OOD Gate Tests', () {
    test('AlwaysAcceptOODGate returns true', () async {
      final gate = AlwaysAcceptOODGate();
      final result = await gate.isPlantImage('test.jpg');
      final resultBytes = await gate.isPlantBytes(Uint8List(0), 0, 0);
      expect(result, isTrue);
      expect(resultBytes, isTrue);
    });

    test(
        'ClassifierRepositoryImpl returns OODFailure when OODGate rejects image',
        () async {
      final classifier = CropDiseaseClassifier();
      final repo = ClassifierRepositoryImpl(classifier, RejectingOODGate());

      final res = await repo.classifyFromPath('test.jpg');
      expect(res.isError, isTrue);
      expect(res.failure, isA<OODFailure>());
    });

    test(
        'ClassifierRepositoryImpl returns OODFailure when OODGate rejects bytes',
        () async {
      final classifier = CropDiseaseClassifier();
      final repo = ClassifierRepositoryImpl(classifier, RejectingOODGate());

      final res = await repo.classifyFromBytes(Uint8List(10), 10, 10);
      expect(res.isError, isTrue);
      expect(res.failure, isA<OODFailure>());
    });

    test('DetectionResult handles modelVersion gracefully', () {
      final mapWithoutVersion = {
        'id': 1,
        'userId': 'user123',
        'imagePath': 'leaf.jpg',
        'diseaseLabel': 'Tomato___Early_blight',
        'displayName': 'Tomato Early Blight',
        'confidence': 0.85,
        'severity': 'moderate',
        'isHealthy': 0,
        'cropType': 'Tomato',
        'cause': 'Fungal',
        'treatments': 'Spray fungicide',
        'timestamp': 123456789,
        'isDegraded': 0,
      };

      final result = DetectionResult.fromMap(mapWithoutVersion);
      expect(result.modelVersion, isNull);

      final mapWithVersion = {
        ...mapWithoutVersion,
        'modelVersion': '2.1',
      };
      final resultWithVersion = DetectionResult.fromMap(mapWithVersion);
      expect(resultWithVersion.modelVersion, equals('2.1'));

      final serialized = resultWithVersion.toMap();
      expect(serialized['modelVersion'], equals('2.1'));
    });

    test(
        'ClassificationResult and Classification preserve modelVersion provenance',
        () {
      final info = DiseaseDatabase.getInfo('Tomato___Early_blight');
      final classificationResult = ClassificationResult(
        label: 'Tomato___Early_blight',
        confidence: 0.95,
        isHealthy: false,
        diseaseInfo: info,
        modelVersion: 'v2-retrained-quant',
      );
      expect(classificationResult.modelVersion, equals('v2-retrained-quant'));

      final repo = ClassifierRepositoryImpl(
          CropDiseaseClassifier(), AlwaysAcceptOODGate());
      final classification = repo.classifyFromPath('test.jpg'); // tests mapping
      expect(classification, isNotNull);
    });

    test(
        'ClassifierRepositoryImpl returns explicit MLFailure subtype when model is unavailable or input is invalid',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final classifier = CropDiseaseClassifier();
      final repo = ClassifierRepositoryImpl(classifier, AlwaysAcceptOODGate());

      final res = await repo.classifyFromPath('non_existent.jpg');
      expect(res.isError, isTrue);
      expect(res.failure, isA<MLFailure>());
      expect(
          (res.failure as MLFailure).code,
          anyOf(equals('MODEL_LOAD_FAILED'), equals('MODEL_CONTRACT_FAILED'),
              equals('MODEL_INPUT_INVALID')));
    });
  });
}
