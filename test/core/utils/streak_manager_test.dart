import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/utils/streak_manager.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StreakManager', () {
    test('getStreak returns 0 when no scan recorded', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      expect(manager.getStreak(), 0);
    });

    test('first scan sets streak to 1', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      await manager.recordScan();
      expect(manager.getStreak(), 1);
    });

    test('scan on same day does not increment streak', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      await manager.recordScan(); // streak = 1
      await manager.recordScan(); // same day → still 1
      expect(manager.getStreak(), 1);
    });

    test('scan after exactly 1 day increments streak', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);

      // Simulate yesterday's scan by manually writing lastScanDate
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await prefs.setInt('streak_count', 3);
      await prefs.setInt('last_scan_date', yesterday);

      await manager.recordScan(); // today → streak should be 4
      expect(manager.getStreak(), 4);
    });

    test('scan after gap of >1 day resets streak to 1', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);

      final now = DateTime.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 3))
          .millisecondsSinceEpoch;
      await prefs.setInt('streak_count', 10);
      await prefs.setInt('last_scan_date', twoDaysAgo);

      await manager.recordScan();
      expect(manager.getStreak(), 1);
    });

    test('getDaysSinceLastScan returns 99 when never scanned', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      expect(manager.getDaysSinceLastScan(), 99);
    });

    test('getDaysSinceLastScan returns 0 for scan recorded today', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      await manager.recordScan();
      expect(manager.getDaysSinceLastScan(), 0);
    });
  });
}
