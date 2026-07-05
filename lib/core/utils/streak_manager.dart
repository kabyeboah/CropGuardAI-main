import 'package:shared_preferences/shared_preferences.dart';

class StreakManager {
  final SharedPreferences _prefs;
  static const _keyStreakCount = "streak_count";
  static const _keyLastScanDate = "last_scan_date";

  StreakManager(this._prefs);

  int getStreak() => _prefs.getInt(_keyStreakCount) ?? 0;

  Future<void> recordScan() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    final lastScan = _prefs.getInt(_keyLastScanDate) ?? 0;

    if (lastScan == 0) {
      await _prefs.setInt(_keyStreakCount, 1);
      await _prefs.setInt(_keyLastScanDate, today);
      return;
    }

    final diff = today - lastScan;
    const oneDay = 24 * 60 * 60 * 1000;

    if (diff == oneDay) {
      await _prefs.setInt(_keyStreakCount, getStreak() + 1);
      await _prefs.setInt(_keyLastScanDate, today);
    } else if (diff > oneDay) {
      await _prefs.setInt(_keyStreakCount, 1);
      await _prefs.setInt(_keyLastScanDate, today);
    }
    // Same day, do nothing
  }

  int getDaysSinceLastScan() {
    final lastScan = _prefs.getInt(_keyLastScanDate) ?? 0;
    if (lastScan == 0) return 99; // Never scanned
    final today = DateTime.now().millisecondsSinceEpoch;
    return ((today - lastScan) / (24 * 60 * 60 * 1000)).toInt();
  }
}
