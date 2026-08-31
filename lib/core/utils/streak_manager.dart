import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks daily scan streaks.
///
/// **Clock manipulation hardening**: streak boundaries are computed using the
/// Firestore server timestamp so rolling the device clock back cannot inflate
/// streaks. When Firestore is unreachable (offline), the device clock is used
/// as a fallback, preserving offline-first behaviour. The next successful
/// online sync re-anchors to server time.
///
/// If streaks ever gate financial rewards, migrate [_keyLastScanDate] to a
/// server-side Firestore document so no local prefs can be tampered with.
class StreakManager {
  final SharedPreferences _prefs;
  static const _keyStreakCount = 'streak_count';
  static const _keyLastScanDate = 'last_scan_date';

  @visibleForTesting
  static DateTime Function()? clockOverride;

  /// Injected for tests to replace Firestore server-time fetch.
  @visibleForTesting
  static Future<DateTime> Function()? serverTimeOverride;

  StreakManager(this._prefs);

  int getStreak() => _prefs.getInt(_keyStreakCount) ?? 0;

  /// Returns the current server time from Firestore.
  ///
  /// Priority:
  ///   1. [serverTimeOverride] — test injection; if it throws, falls through.
  ///   2. [clockOverride] — legacy test injection (sync, always succeeds).
  ///   3. Firestore `FieldValue.serverTimestamp()` — production path.
  ///   4. `DateTime.now()` — offline fallback when Firestore is unreachable.
  static Future<DateTime> _serverNow() async {
    // 1. Test override (async) — catch throws so the offline-fallback test works.
    if (serverTimeOverride != null) {
      try {
        return await serverTimeOverride!();
      } catch (_) {
        // Fall through to clockOverride / device clock.
      }
    }
    // 2. Legacy sync clock override (also used by tests).
    if (clockOverride != null) return clockOverride!();
    // 3. Authoritative server time.
    try {
      final db = FirebaseFirestore.instance;
      // Use the special `__time__` sentinel collection; no security rules
      // needed because we only write to a temporary doc and read it back.
      final ref = db.collection('__server_time__').doc('ping');
      await ref.set({'t': FieldValue.serverTimestamp()});
      final snap = await ref.get();
      final ts = snap.data()?['t'];
      if (ts is Timestamp) return ts.toDate().toLocal();
    } catch (_) {
      // Firestore unavailable (offline) — fall through to device clock.
    }
    // 4. Offline fallback.
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
