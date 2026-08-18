import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/utils/streak_manager.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Use server-time override so tests run without a live Firestore instance.
    // Each test group sets its own date; tearDown resets to null.
    StreakManager.serverTimeOverride = null;
    StreakManager.clockOverride = null;
  });

  tearDown(() {
    StreakManager.serverTimeOverride = null;
    StreakManager.clockOverride = null;
  });

  group('StreakManager', () {
    test('getStreak returns 0 when no scan recorded', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      expect(manager.getStreak(), 0);
    });

    test('first scan sets streak to 1', () async {
      final now = DateTime(2024, 6, 1);
      StreakManager.serverTimeOverride = () async => now;

      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      await manager.recordScan();
      expect(manager.getStreak(), 1);
    });

    test('scan on same day does not increment streak', () async {
      final now = DateTime(2024, 6, 1);
      StreakManager.serverTimeOverride = () async => now;

      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      await manager.recordScan(); // streak = 1
      await manager.recordScan(); // same day → still 1
      expect(manager.getStreak(), 1);
    });

    test('scan after exactly 1 day increments streak', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);

      // Seed yesterday via prefs directly (simulates a prior recorded scan).
      final yesterday = DateTime(2024, 6, 1).millisecondsSinceEpoch;
      await prefs.setInt('streak_count', 3);
      await prefs.setInt('last_scan_date', yesterday);

      // Server time is tomorrow.
      StreakManager.serverTimeOverride =
          () async => DateTime(2024, 6, 2, 10); // 10:00 on June 2

      await manager.recordScan(); // today → streak should be 4
      expect(manager.getStreak(), 4);
    });

    test('scan after gap of >1 day resets streak to 1', () async {
      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);

      final threeDaysAgo = DateTime(2024, 5, 29).millisecondsSinceEpoch;
      await prefs.setInt('streak_count', 10);
      await prefs.setInt('last_scan_date', threeDaysAgo);

      StreakManager.serverTimeOverride = () async => DateTime(2024, 6, 1);

      await manager.recordScan();
      expect(manager.getStreak(), 1);
    });

    test('getDaysSinceLastScan returns 99 when never scanned', () async {
      StreakManager.serverTimeOverride = () async => DateTime(2024, 6, 1);

      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      expect(await manager.getDaysSinceLastScan(), 99);
    });

    test('getDaysSinceLastScan returns 0 for scan recorded today', () async {
      final today = DateTime(2024, 6, 1);
      StreakManager.serverTimeOverride = () async => today;

      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      await manager.recordScan();
      expect(await manager.getDaysSinceLastScan(), 0);
    });

    test('falls back to device clock when serverTimeOverride returns future error',
        () async {
      // Simulate offline: serverTimeOverride throws, clockOverride is set.
      StreakManager.serverTimeOverride = () async => throw Exception('offline');
      StreakManager.clockOverride = () => DateTime(2024, 6, 1);

      final prefs = await SharedPreferences.getInstance();
      final manager = StreakManager(prefs);
      // _serverNow catches the exception and falls through to clockOverride.
      // Since clockOverride is checked before the Firestore call, recordScan
      // still succeeds.
      await manager.recordScan();
      expect(manager.getStreak(), 1);
    });
  });
}

