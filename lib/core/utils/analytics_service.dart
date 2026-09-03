import 'package:flutter/widgets.dart';

import 'app_logger.dart';
import 'diagnostic_sanitizer.dart';

/// Clean privacy-first AnalyticsService for product funnel tracking.
///
/// Every call is best-effort and swallows errors so analytics can never crash a
/// user flow. When user consent is disabled, no tracking occurs.
class AnalyticsService {
  bool _enabled = false;
  final List<Map<String, dynamic>> _inMemoryEvents = [];

  bool get isEnabled => _enabled;
  List<Map<String, dynamic>> get recordedEvents => List.unmodifiable(_inMemoryEvents);

  NavigatorObserver get observer => _AnalyticsNavigatorObserver(this);

  /// Applies the user's analytics consent.
  /// Persisted by SettingsProvider and re-applied on startup.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    AppLogger.setCrashlyticsEnabled(enabled);
    if (!enabled) {
      _inMemoryEvents.clear();
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_enabled) return;
    try {
      final cleanParams =
          params != null ? DiagnosticSanitizer.sanitizeMap(params) : null;
      _inMemoryEvents.add({
        'name': name,
        'params': cleanParams,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (_inMemoryEvents.length > 500) {
        _inMemoryEvents.removeAt(0);
      }
      AppLogger.d('Analytics: $name ${cleanParams ?? ""}');
    } catch (e, s) {
      AppLogger.e('Analytics event "$name" failed', e, s);
    }
  }

  Future<void> setUser({required bool isAnonymous}) async {
    if (!_enabled) return;
    AppLogger.d('Analytics: setUser(isAnonymous: $isAnonymous)');
  }

  // ── Funnel events ──────────────────────────────────────────────────────────

  Future<void> logScanStarted({required String source}) =>
      _log('scan_started', {'source': source}); // camera | gallery | batch

  Future<void> logScanCompleted({
    required String disease,
    required double confidence,
    required bool isHealthy,
    String? modelVersion,
    List<({String label, double confidence})> topCandidates = const [],
  }) =>
      _log('scan_completed', {
        'disease': disease,
        'confidence': (confidence * 100).round(),
        'is_healthy': isHealthy.toString(),
        if (modelVersion != null) 'model_version': modelVersion,
        if (topCandidates.isNotEmpty)
          'top_candidates': topCandidates
              .map((c) => '${c.label}:${(c.confidence * 100).round()}')
              .join(','),
      });

  Future<void> logLowConfidence({
    required double confidence,
    String? disease,
    String? modelVersion,
  }) =>
      _log('scan_low_confidence', {
        'confidence': (confidence * 100).round(),
        if (disease != null) 'disease': disease,
        if (modelVersion != null) 'model_version': modelVersion,
      });

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

  Future<void> logCommunityPostSubmitted() => _log('community_post_submitted');

  Future<void> logOutbreakReported() => _log('outbreak_reported');

  Future<void> logTreatmentPlanCreated() => _log('treatment_plan_created');

  Future<void> logFeedbackCorrectionSubmitted() =>
      _log('feedback_correction_submitted');

  Future<void> logAppLockTriggered() => _log('app_lock_triggered');

  Future<void> logOfflineQueueDrain({required int count}) =>
      _log('offline_queue_drain', {'count': count});

  Future<void> logModelFallbackUsed({required String reason}) =>
      _log('model_fallback_used', {'reason': reason});
}

class _AnalyticsNavigatorObserver extends NavigatorObserver {
  final AnalyticsService _service;
  _AnalyticsNavigatorObserver(this._service);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      _service._log('screen_view', {'screen_name': name});
    }
  }
}
