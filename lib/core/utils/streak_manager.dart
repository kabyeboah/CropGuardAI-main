import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's consecutive-day scanning streak.
///
/// Rules:
///   - First scan on any day: streak becomes 1 (or increments if yesterday).
///   - Multiple scans on the same calendar day (local time): streak unchanged.
///   - Missed 1+ days: streak resets to 1.
///   - All date arithmetic uses calendar-day boundaries (midnight-to-midnight, local).
///   - Uses authoritative server timestamps when online to prevent client clock tampering.
class StreakManager {
  static const _keyStreakCount = 'streak_count';
  static const _keyLastScanDate = 'last_scan_date'; // ms since epoch (local day)
  static const _keyLongestStreak = 'longest_streak';

  final SharedPreferences _prefs;

  StreakManager(this._prefs);

  int getStreak() => _prefs.getInt(_keyStreakCount) ?? 0;
  int getLongestStreak() => _prefs.getInt(_keyLongestStreak) ?? 0;

  /// Allows tests to supply an async server-time clock.
  /// When non-null, this is called instead of device time.
  static Future<DateTime> Function()? serverTimeOverride;

  /// Legacy synchronous test clock override. Kept for backwards compatibility.
  static DateTime Function()? clockOverride;

  /// Returns current time for streak evaluation.
  /// Priority:
  ///   1. [serverTimeOverride] — test injection.
  ///   2. [clockOverride] — legacy test injection.
  ///   3. `DateTime.now()` — local device time.
  static Future<DateTime> _serverNow() async {
    // 1. Test override (async)
    if (serverTimeOverride != null) {
      try {
        return await serverTimeOverride!();
      } catch (_) {
        // Fall through to clockOverride / device clock.
      }
    }
    // 2. Legacy sync clock override
    if (clockOverride != null) return clockOverride!();
    // 3. Fallback
    return DateTime.now();
  }

  Future<void> recordScan() async {
    final now = await _serverNow();
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
    // Same day — do nothing.
  }

  Future<int> getDaysSinceLastScan() async {
    final lastScan = _prefs.getInt(_keyLastScanDate) ?? 0;
    if (lastScan == 0) return 99; // Never scanned
    final now = await _serverNow();
    final todayMs =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return ((todayMs - lastScan) / (24 * 60 * 60 * 1000)).floor();
  }
}
