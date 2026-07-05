import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/core/utils/scan_severity.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/presentation/screens/result/batch_result_provider.dart';

DetectionResult _det({required double confidence, required bool isHealthy}) {
  return DetectionResult(
    id: 1,
    userId: 'u',
    imagePath: '/img.jpg',
    diseaseLabel: isHealthy ? 'Tomato___healthy' : 'Tomato___Late_blight',
    displayName: isHealthy ? 'Healthy' : 'Late Blight',
    confidence: confidence,
    severity: ScanSeverity.early,
    isHealthy: isHealthy,
    cropType: 'Tomato',
    cause: '',
    treatments: const [],
    timestamp: 0,
  );
}

void main() {
  group('BatchResultProvider.calculateResults severity', () {
    test('diseased with avg confidence < 0.60 is marked unclear, not early', () {
      final provider = BatchResultProvider();
      provider.calculateResults([
        _det(confidence: 0.50, isHealthy: false),
        _det(confidence: 0.40, isHealthy: false),
      ]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.unclear);
    });

    test('diseased with avg confidence in [0.60,0.75) is early', () {
      final provider = BatchResultProvider();
      provider.calculateResults([_det(confidence: 0.65, isHealthy: false)]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.early);
    });

    test('diseased with high avg confidence is severe', () {
      final provider = BatchResultProvider();
      provider.calculateResults([_det(confidence: 0.95, isHealthy: false)]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.severe);
    });

    test('all-healthy batch is healthy', () {
      final provider = BatchResultProvider();
      provider.calculateResults([_det(confidence: 0.9, isHealthy: true)]);
      expect(provider.batchResult!.overallSeverity, ScanSeverity.healthy);
    });
  });
}
