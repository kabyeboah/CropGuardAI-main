import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadModel gracefully handles environment engine availability', () async {
    final classifier = CropDiseaseClassifier();
    await classifier.loadModel();

    // In unit test environment without native libtensorflowlite_c linked, engine falls back cleanly
    if (!classifier.isEngineAvailable) {
      expect(classifier.isLoaded, isFalse);

      final tempDir = Directory.systemTemp.createTempSync();
      final dummyPath = '${tempDir.path}/test_image.jpg';
      File(dummyPath).writeAsBytesSync([0, 1, 2, 3]);

      final result = await classifier.classifyFromPath(dummyPath);
      expect(result, isNotNull);
      expect(result!.engineUnavailable, isTrue);
      expect(result.isDegraded, isTrue);
    } else {
      expect(classifier.isLoaded, isTrue);
    }

    classifier.close();
  });
}
