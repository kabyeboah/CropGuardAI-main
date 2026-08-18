import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/core/utils/scan_severity.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/presentation/screens/result/batch_result_provider.dart';

DetectionResult _det({
  required double confidence,
  required bool isHealthy,
  String severity = ScanSeverity.early,
}) {
  return DetectionResult(
    id: 1,
    userId: 'u',
    imagePath: '/img.jpg',
    diseaseLabel: isHealthy ? 'Tomato___healthy' : 'Tomato___Late_blight',
    displayName: isHealthy ? 'Healthy' : 'Late Blight',
    confidence: confidence,
    severity: isHealthy ? ScanSeverity.healthy : severity,
    isHealthy: isHealthy,
    cropType: 'Tomato',
    cause: '',
    treatments: const [],
    timestamp: 0,
  );
}

void main() {
  group('BatchResultProvider.calculateResults severity', () {
    test('diseased batch overallSeverity matches highest individual leaf severity', () {
      final provider = BatchResultProvider();
      provider.calculateResults([
        _det(confidence: 0.99, isHealthy: false, severity: ScanSeverity.early),
        _det(confidence: 0.85, isHealthy: false, severity: ScanSeverity.severe),
        _det(confidence: 0.90, isHealthy: false, severity: ScanSeverity.moderate),
      ]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.severe);
    });

    test('diseased batch with unclear severity uses unclear when no higher severity present', () {
      final provider = BatchResultProvider();
      provider.calculateResults([
        _det(confidence: 0.50, isHealthy: false, severity: ScanSeverity.unclear),
      ]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.unclear);
    });

    test('all-healthy batch is healthy', () {
      final provider = BatchResultProvider();
      provider.calculateResults([_det(confidence: 0.9, isHealthy: true)]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.healthy);
    });
  });
}
