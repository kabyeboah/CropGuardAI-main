import 'package:firebase_analytics/firebase_analytics.dart';

import 'app_logger.dart';

/// Thin wrapper around Firebase Analytics for product funnel tracking.
///
/// Every call is best-effort and swallows errors so analytics can never crash a
/// user flow. Keep event names <=40 chars and snake_case (Firebase constraint).
/// The matching navigator observer ([observer]) is wired in `app.dart` to log
/// `screen_view` automatically for go_router routes.
class AnalyticsService {
  AnalyticsService([FirebaseAnalytics? analytics])
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  /// User-controlled consent (Settings → "Share usage analytics"). When false,
  /// no events are sent and Firebase collection is disabled at the SDK level.
  bool _enabled = true;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Applies the user's analytics consent. Persisted by SettingsProvider and
  /// re-applied on startup.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {/* best-effort */}
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled) return;
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e, s) {
      AppLogger.e('Analytics event "$name" failed', e, s);
    }
  }

  Future<void> setUser({required bool isAnonymous}) async {
    if (!_enabled) return;
    try {
      await _analytics.setUserProperty(
          name: 'is_anonymous', value: isAnonymous.toString());
    } catch (_) {/* best-effort */}
  }

  // ── Funnel events ──────────────────────────────────────────────────────────

  Future<void> logScanStarted({required String source}) =>
      _log('scan_started', {'source': source}); // camera | gallery | batch

  Future<void> logScanCompleted({
    required String disease,
    required double confidence,
    required bool isHealthy,
  }) =>
      _log('scan_completed', {
        'disease': disease,
        'confidence': (confidence * 100).round(),
        'is_healthy': isHealthy.toString(),
      });

  Future<void> logLowConfidence({required double confidence}) =>
      _log('scan_low_confidence', {'confidence': (confidence * 100).round()});

  Future<void> logScanFailed({required String reason}) =>
      _log('scan_failed', {'reason': reason});

  Future<void> logResultShared({required String disease}) =>
      _log('result_shared', {'disease': disease});

  Future<void> logExpertHelpRequested() => _log('expert_help_requested');

  Future<void> logLogin({required String method}) =>
      _log('login', {'method': method}); // email | google | anonymous

  Future<void> logSignUp({required String method}) =>
      _log('sign_up', {'method': method});

  Future<void> logColdStart(int durationMs) =>
      _log('cold_start_time', {'duration_ms': durationMs});
}
