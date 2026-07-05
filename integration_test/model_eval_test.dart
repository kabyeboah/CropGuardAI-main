// Model accuracy evaluation harness.
//
// Runs the production [CropDiseaseClassifier] over a labelled test set and
// prints per-class precision/recall/F1, a confusion matrix and overall
// accuracy. This is an integration test (not a unit test) because the
// classifier needs Flutter asset loading and the TFLite native runtime, which
// only exist on a real device/emulator.
//
// USAGE
//   1. Build a held-out test set the model has NEVER trained on. Lay it out
//      ImageNet-style — one sub-folder per class, named EXACTLY as the labels
//      in assets/labels.txt:
//        test_set/
//          Tomato___Late_blight/img1.jpg ...
//          Tomato___healthy/imgA.jpg ...
//   2. Push it to the device and point the harness at it:
//        adb push ./test_set /data/local/tmp/cropguard_test_set
//        flutter test integration_test/model_eval_test.dart \
//          --dart-define=TEST_SET_DIR=/data/local/tmp/cropguard_test_set
//   3. Read the printed report. Commit it to docs/MODEL_ACCURACY.md so the
//      claimed accuracy is auditable.
//
// If TEST_SET_DIR is unset or empty the test is skipped (so CI stays green).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';

const _testSetDir = String.fromEnvironment('TEST_SET_DIR');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('crop disease model accuracy on held-out set', () async {
    if (_testSetDir.isEmpty) {
      markTestSkipped('TEST_SET_DIR not provided — skipping model evaluation.');
      return;
    }

    final root = Directory(_testSetDir);
    expect(root.existsSync(), isTrue,
        reason: 'TEST_SET_DIR does not exist: $_testSetDir');

    final classifier = CropDiseaseClassifier();
    await classifier.loadModel();

    // Gather (imagePath, trueLabel) pairs from sub-folders.
    final samples = <MapEntry<String, String>>[];
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final label = entity.path.split(Platform.pathSeparator).last;
      for (final file in entity.listSync()) {
        if (file is File && _isImage(file.path)) {
          samples.add(MapEntry(file.path, label));
        }
      }
    }
    expect(samples, isNotEmpty,
        reason: 'No images found under $_testSetDir (expected class sub-folders)');

    // Confusion matrix: trueLabel -> (predictedLabel -> count).
    final confusion = <String, Map<String, int>>{};
    final classes = <String>{};
    var correct = 0;

    for (final sample in samples) {
      final result = await classifier.classifyFromPath(sample.key);
      final predicted = result?.label ?? 'Unknown';
      final truth = sample.value;
      classes
        ..add(truth)
        ..add(predicted);
      confusion.putIfAbsent(truth, () => {});
      confusion[truth]![predicted] = (confusion[truth]![predicted] ?? 0) + 1;
      if (predicted == truth) correct++;
    }

    final total = samples.length;
    final accuracy = correct / total;

    // Per-class precision / recall / F1.
    final buffer = StringBuffer()
      ..writeln('\n===== CropGuard model evaluation =====')
      ..writeln('Test set : $_testSetDir')
      ..writeln('Samples  : $total')
      ..writeln('Accuracy : ${(accuracy * 100).toStringAsFixed(2)}%')
      ..writeln('\nPer-class metrics:')
      ..writeln('label                                    prec   recall   f1     support');

    final sortedClasses = classes.toList()..sort();
    for (final c in sortedClasses) {
      final tp = confusion[c]?[c] ?? 0;
      var fp = 0; // predicted c but truth != c
      var support = 0; // truth == c
      for (final truth in confusion.keys) {
        final preds = confusion[truth]!;
        if (truth == c) {
          support = preds.values.fold(0, (a, b) => a + b);
        } else {
          fp += preds[c] ?? 0;
        }
      }
      final precision = (tp + fp) == 0 ? 0.0 : tp / (tp + fp);
      final recall = support == 0 ? 0.0 : tp / support;
      final f1 = (precision + recall) == 0
          ? 0.0
          : 2 * precision * recall / (precision + recall);
      buffer.writeln('${c.padRight(40)} '
          '${precision.toStringAsFixed(2)}   '
          '${recall.toStringAsFixed(2)}    '
          '${f1.toStringAsFixed(2)}   '
          '$support');
    }

    buffer.writeln('\nConfusion (truth -> predictions):');
    for (final truth in sortedClasses) {
      final preds = confusion[truth];
      if (preds == null) continue;
      final entries = preds.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln('  $truth -> ${entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    }

    // Printed via test output; copy into docs/MODEL_ACCURACY.md.
    // ignore: avoid_print
    print(buffer.toString());

    // Guardrail: a disease-detection app below this bar should not ship.
    // Tune once a real baseline exists.
    expect(accuracy, greaterThan(0.70),
        reason: 'Model accuracy ${(accuracy * 100).toStringAsFixed(2)}% '
            'is below the 70% shipping threshold.');
  });
}

bool _isImage(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
}
