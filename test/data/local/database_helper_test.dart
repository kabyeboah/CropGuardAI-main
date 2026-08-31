import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';

/// Verifies that the per-user scoping of farm stats / daily trend is honoured,
/// so one account never sees another account's detections in its totals.
void main() {
  setUpAll(() {
    // Run sqflite against the FFI implementation so it works in a pure Dart
    // unit-test environment (no Android/iOS platform channels available).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;

  setUp(() async {
    // A fresh in-memory database per test keeps cases fully isolated.
    databaseFactory = databaseFactoryFfi;
    db = DatabaseHelper();
    await db.deleteAllDetections();
  });

  DetectionResult detection({
    required String userId,
    required bool isHealthy,
    int? timestamp,
  }) {
    return DetectionResult(
      userId: userId,
      imagePath: '',
      diseaseLabel: isHealthy ? 'healthy' : 'blight',
      displayName: isHealthy ? 'Healthy' : 'Blight',
      confidence: 0.9,
      isHealthy: isHealthy,
      cropType: 'tomato',
      cause: '',
      treatments: const [],
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  group('getFarmStats', () {
    test('counts every detection when no userId is given', () async {
      await db.insertDetection(detection(userId: 'alice', isHealthy: true));
      await db.insertDetection(detection(userId: 'alice', isHealthy: false));
      await db.insertDetection(detection(userId: 'bob', isHealthy: false));

      final stats = await db.getFarmStats();

      expect(stats['total'], 3);
      expect(stats['healthy'], 1);
      expect(stats['diseased'], 2);
    });

    test('only counts the requested user\'s detections', () async {
      await db.insertDetection(detection(userId: 'alice', isHealthy: true));
      await db.insertDetection(detection(userId: 'alice', isHealthy: false));
      await db.insertDetection(detection(userId: 'bob', isHealthy: false));

      final stats = await db.getFarmStats(userId: 'alice');

      expect(stats['total'], 2);
      expect(stats['healthy'], 1);
      expect(stats['diseased'], 1);
    });

    test('returns zeroes for a user with no detections', () async {
      await db.insertDetection(detection(userId: 'alice', isHealthy: true));

      final stats = await db.getFarmStats(userId: 'bob');

      expect(stats['total'], 0);
      expect(stats['healthy'], 0);
      expect(stats['diseased'], 0);
    });
  });

  group('getDailyTrend', () {
    test('only includes the requested user within the window', () async {
      final today = DateTime.now().millisecondsSinceEpoch;
      await db.insertDetection(
          detection(userId: 'alice', isHealthy: true, timestamp: today));
      await db.insertDetection(
          detection(userId: 'alice', isHealthy: false, timestamp: today));
      await db.insertDetection(
          detection(userId: 'bob', isHealthy: false, timestamp: today));

      final trend = await db.getDailyTrend(days: 7, userId: 'alice');

      final healthy =
          trend.fold<int>(0, (sum, row) => sum + (row['healthyCount'] as int));
      final diseased =
          trend.fold<int>(0, (sum, row) => sum + (row['diseasedCount'] as int));

      expect(healthy, 1);
      expect(diseased, 1);
    });

    test('excludes detections older than the window', () async {
      final old = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      await db.insertDetection(
          detection(userId: 'alice', isHealthy: false, timestamp: old));

      final trend = await db.getDailyTrend(days: 7, userId: 'alice');

      expect(trend, isEmpty);
    });
  });
}
