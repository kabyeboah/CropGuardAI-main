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
    treatments: [
      'Remove infected leaves',
      'Apply fungicide',
      'Improve drainage'
    ],
    timestamp: 1700000000000,
  );

  group('DetectionResult toMap / fromMap round-trip', () {
    test('all fields survive a toMap → fromMap round-trip', () {
      final withExtras = tResult.copyWith(
        remoteId: 'uuid-1234-5678',
        topCandidates: [
          (label: 'Tomato___Late_blight', confidence: 0.91),
          (label: 'Tomato___Early_blight', confidence: 0.08),
        ],
      );
      final map = withExtras.toMap();
      final restored = DetectionResult.fromMap(map);

      expect(restored.id, withExtras.id);
      expect(restored.remoteId, 'uuid-1234-5678');
      expect(restored.userId, withExtras.userId);
      expect(restored.imagePath, withExtras.imagePath);
      expect(restored.diseaseLabel, withExtras.diseaseLabel);
      expect(restored.displayName, withExtras.displayName);
      expect(restored.confidence, withExtras.confidence);
      expect(restored.severity, withExtras.severity);
      expect(restored.isHealthy, withExtras.isHealthy);
      expect(restored.cropType, withExtras.cropType);
      expect(restored.cause, withExtras.cause);
      expect(restored.treatments, withExtras.treatments);
      expect(restored.timestamp, withExtras.timestamp);
      expect(restored.isSynced, withExtras.isSynced);
      expect(restored.syncedAt, withExtras.syncedAt);
      expect(restored.topCandidates.length, 2);
      expect(restored.topCandidates[0].label, 'Tomato___Late_blight');
      expect(restored.topCandidates[0].confidence, 0.91);
      expect(restored.topCandidates[1].label, 'Tomato___Early_blight');
      expect(restored.topCandidates[1].confidence, 0.08);
    });

    test('isSynced and syncedAt round-trip correctly', () {
      final synced = tResult.copyWith(isSynced: true, syncedAt: 1700000005000);
      final map = synced.toMap();
      expect(map['isSynced'], 1);
      expect(map['syncedAt'], 1700000005000);

      final restored = DetectionResult.fromMap(map);
      expect(restored.isSynced, isTrue);
      expect(restored.syncedAt, 1700000005000);
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
