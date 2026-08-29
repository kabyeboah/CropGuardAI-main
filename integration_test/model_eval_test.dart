// Model accuracy evaluation harness.
//
// Runs the production [CropDiseaseClassifier] over a labelled test set and
// prints per-class precision/recall/F1, macro F1, weighted F1, threshold
// coverage/accuracy, expected calibration error (ECE), and a confusion matrix.
//
// This is an integration test (not a unit test) because the classifier needs
// Flutter asset loading and the native ML runtime when available, which only
// exist on a real device/emulator.
//
// USAGE
//   1. Build a held-out test set the model has NEVER trained on. Lay it out
//      ImageNet-style — one sub-folder per class, named EXACTLY as the labels
//      in assets/labels_verified.txt:
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

class _PredictionRecord {
  final String imagePath;
  final String trueLabel;
  final String predictedLabel;
  final double confidence;
  final bool isCorrect;

  const _PredictionRecord({
    required this.imagePath,
    required this.trueLabel,
    required this.predictedLabel,
    required this.confidence,
    required this.isCorrect,
  });
}

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
    final groundTruthClasses = <String>{};
    final records = <_PredictionRecord>[];
    var correct = 0;

    for (final sample in samples) {
      final result = await classifier.classifyFromPath(sample.key);
      final predicted = result?.label ?? 'Unknown';
      final confidence = result?.confidence ?? 0.0;
      final truth = sample.value;

      groundTruthClasses.add(truth);
      classes
        ..add(truth)
        ..add(predicted);
      confusion.putIfAbsent(truth, () => {});
      confusion[truth]![predicted] = (confusion[truth]![predicted] ?? 0) + 1;

      final isCorrect = (predicted == truth);
      if (isCorrect) correct++;

      records.add(_PredictionRecord(
        imagePath: sample.key,
        trueLabel: truth,
        predictedLabel: predicted,
        confidence: confidence,
        isCorrect: isCorrect,
      ));
    }

    final total = samples.length;
    final accuracy = total > 0 ? correct / total : 0.0;

    // Filter by production threshold (0.60).
    final confidentRecords = records
        .where((r) => r.confidence >= CropDiseaseClassifier.confidenceThreshold)
        .toList();
    final confidentCount = confidentRecords.length;
    final confidentCorrect =
        confidentRecords.where((r) => r.isCorrect).length;
    final confidentAccuracy =
        confidentCount > 0 ? confidentCorrect / confidentCount : 0.0;
    final coverage = total > 0 ? confidentCount / total : 0.0;

    // Calculate Expected Calibration Error (ECE) across 10 bins.
    const numBins = 10;
    var totalEce = 0.0;
    for (var b = 0; b < numBins; b++) {
      final binLower = b / numBins;
      final binUpper = (b + 1) / numBins;
      final binRecords = records.where((r) {
        if (b == numBins - 1) {
          return r.confidence >= binLower && r.confidence <= binUpper;
        }
        return r.confidence >= binLower && r.confidence < binUpper;
      }).toList();

      if (binRecords.isNotEmpty) {
        final binAcc =
            binRecords.where((r) => r.isCorrect).length / binRecords.length;
        final binConf = binRecords
                .map((r) => r.confidence)
                .reduce((a, b) => a + b) /
            binRecords.length;
        final binWeight = binRecords.length / total;
        totalEce += (binAcc - binConf).abs() * binWeight;
      }
    }

    // Per-class precision / recall / F1.
    final sortedClasses = classes.toList()..sort();
    final perClassF1 = <String, double>{};
    final perClassSupport = <String, int>{};

    final buffer = StringBuffer()
      ..writeln('\n======================================================')
      ..writeln('        CropGuard AI Model Evaluation Report')
      ..writeln('======================================================')
      ..writeln('Test set path       : $_testSetDir')
      ..writeln('Total samples       : $total')
      ..writeln('Overall Top-1 Acc   : ${(accuracy * 100).toStringAsFixed(2)}% ($correct / $total)')
      ..writeln('Threshold (τ)       : ${CropDiseaseClassifier.confidenceThreshold.toStringAsFixed(2)}')
      ..writeln('Confident Coverage  : ${(coverage * 100).toStringAsFixed(2)}% ($confidentCount / $total)')
      ..writeln('Confident Accuracy  : ${(confidentAccuracy * 100).toStringAsFixed(2)}% ($confidentCorrect / $confidentCount)')
      ..writeln('Expected Cal. Error : ${(totalEce * 100).toStringAsFixed(2)}% (ECE, 10 bins)')
      ..writeln('------------------------------------------------------')
      ..writeln('\nPer-class metrics (Markdown table format):')
      ..writeln('| Class Label | Precision | Recall | F1-Score | Support |')
      ..writeln('|-------------|-----------|--------|----------|---------|');

    var weightedF1Sum = 0.0;
    var macroF1Sum = 0.0;
    var totalGroundTruthSupport = 0;

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

      perClassF1[c] = f1;
      perClassSupport[c] = support;

      if (groundTruthClasses.contains(c)) {
        macroF1Sum += f1;
        weightedF1Sum += f1 * support;
        totalGroundTruthSupport += support;
      }

      buffer.writeln('| `$c` | ${precision.toStringAsFixed(3)} | ${recall.toStringAsFixed(3)} | ${f1.toStringAsFixed(3)} | $support |');
    }

    final macroF1 = groundTruthClasses.isNotEmpty
        ? macroF1Sum / groundTruthClasses.length
        : 0.0;
    final weightedF1 = totalGroundTruthSupport > 0
        ? weightedF1Sum / totalGroundTruthSupport
        : 0.0;

    buffer
      ..writeln('------------------------------------------------------')
      ..writeln('Macro F1            : ${(macroF1 * 100).toStringAsFixed(2)}%')
      ..writeln('Weighted F1         : ${(weightedF1 * 100).toStringAsFixed(2)}%')
      ..writeln('\nConfusion Details (truth -> predictions):');

    for (final truth in sortedClasses) {
      final preds = confusion[truth];
      if (preds == null) continue;
      final entries = preds.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln('  $truth -> ${entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    }

    // ignore: avoid_print
    print(buffer.toString());

    // Guardrail: a disease-detection app below this bar should not ship.
    expect(accuracy, greaterThan(0.70),
        reason: 'Model accuracy ${(accuracy * 100).toStringAsFixed(2)}% '
            'is below the 70% shipping threshold.');
  });
}

bool _isImage(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
}
