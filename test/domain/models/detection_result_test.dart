import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/core/utils/scan_severity.dart';

void main() {
  const tResult = DetectionResult(
    id: 7,
    userId: 'user_42',
    imagePath: '/data/user/0/images/scan.jpg',
    diseaseLabel: 'Tomato___Late_blight',
    displayName: 'Late Blight',
    confidence: 0.91,
    severity: ScanSeverity.severe,
    isHealthy: false,
    cropType: 'Tomato',
    cause: 'Phytophthora infestans',
    treatments: ['Remove infected leaves', 'Apply fungicide', 'Improve drainage'],
    timestamp: 1700000000000,
  );

  group('DetectionResult toMap / fromMap round-trip', () {
    test('all fields survive a toMap → fromMap round-trip', () {
      final map = tResult.toMap();
      final restored = DetectionResult.fromMap(map);

      expect(restored.id, tResult.id);
      expect(restored.userId, tResult.userId);
      expect(restored.imagePath, tResult.imagePath);
      expect(restored.diseaseLabel, tResult.diseaseLabel);
      expect(restored.displayName, tResult.displayName);
      expect(restored.confidence, tResult.confidence);
      expect(restored.severity, tResult.severity);
      expect(restored.isHealthy, tResult.isHealthy);
      expect(restored.cropType, tResult.cropType);
      expect(restored.cause, tResult.cause);
      expect(restored.treatments, tResult.treatments);
      expect(restored.timestamp, tResult.timestamp);
    });

    test('treatments list is serialized as pipe-separated string', () {
      final map = tResult.toMap();
      expect(
        map['treatments'],
        'Remove infected leaves||Apply fungicide||Improve drainage',
      );
    });

    test('single treatment round-trips correctly', () {
      final single = tResult.copyWith(treatments: ['Water regularly']);
      final map = single.toMap();
      expect(map['treatments'], 'Water regularly');
      expect(DetectionResult.fromMap(map).treatments, ['Water regularly']);
    });

    test('empty treatments round-trips to empty list', () {
      final noTreatments = tResult.copyWith(treatments: []);
      final map = noTreatments.toMap();
      expect(DetectionResult.fromMap(map).treatments, isEmpty);
    });

    test('isHealthy is stored as 1/0 integer', () {
      final healthyMap = tResult.copyWith(isHealthy: true).toMap();
      final diseasedMap = tResult.copyWith(isHealthy: false).toMap();
      expect(healthyMap['isHealthy'], 1);
      expect(diseasedMap['isHealthy'], 0);
    });

    test('fromMap uses safe defaults for missing keys', () {
      final minimal = DetectionResult.fromMap({
        'id': 1,
        'imagePath': '/tmp/x.jpg',
        'diseaseLabel': 'Unknown',
        'displayName': 'Unknown',
        'confidence': 0.5,
        'isHealthy': 0,
        'cropType': 'Unknown',
        'cause': '',
        'treatments': '',
        'timestamp': 0,
      });

      expect(minimal.userId, '');
      expect(minimal.severity, ScanSeverity.unclear);
      expect(minimal.treatments, isEmpty);
    });
  });

  group('DetectionResult copyWith', () {
    test('returns a new instance with only the changed field updated', () {
      final updated = tResult.copyWith(confidence: 0.5);
      expect(updated.confidence, 0.5);
      expect(updated.imagePath, tResult.imagePath);
      expect(updated.treatments, tResult.treatments);
    });
  });
}
