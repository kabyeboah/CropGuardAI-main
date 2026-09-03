import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';

void main() {
  group('DiseaseDatabase 51-Class Verification', () {
    late List<String> labels;

    setUpAll(() {
      final labelsFile = File('assets/labels.txt');
      expect(labelsFile.existsSync(), isTrue);
      labels = labelsFile
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    });

    test('labels.txt contains exactly 51 classes', () {
      expect(labels.length, 51);
    });

    test('every label in labels.txt has a valid DiseaseInfo entry in DiseaseDatabase', () {
      final missing = <String>[];
      for (final label in labels) {
        final info = DiseaseDatabase.getInfo(label);
        if (info.severity == 'unclear' || info.cause == 'Information not available in database') {
          missing.add(label);
        }
      }
      expect(missing, isEmpty, reason: 'Labels missing from DiseaseDatabase: $missing');
    });
  });
}
