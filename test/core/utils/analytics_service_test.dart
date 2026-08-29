import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/analytics_service.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late _MockFirebaseAnalytics analytics;
  late AnalyticsService service;

  setUp(() {
    analytics = _MockFirebaseAnalytics();
    when(() => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenAnswer((_) async {});
    service = AnalyticsService(analytics);
  });

  test('logScanCompleted sends scan_completed with rounded confidence', () async {
    await service.logScanCompleted(
      disease: 'Tomato___Late_blight',
      confidence: 0.873,
      isHealthy: false,
    );

    final captured = verify(() => analytics.logEvent(
          name: captureAny(named: 'name'),
          parameters: captureAny(named: 'parameters'),
        )).captured;

    expect(captured[0], 'scan_completed');
    final params = captured[1] as Map<String, Object>;
    expect(params['disease'], 'Tomato___Late_blight');
    expect(params['confidence'], 87); // (0.873 * 100).round()
    expect(params['is_healthy'], 'false');
  });

  test('logLogin tags the sign-in method', () async {
    await service.logLogin(method: 'google');

    final captured = verify(() => analytics.logEvent(
          name: captureAny(named: 'name'),
          parameters: captureAny(named: 'parameters'),
        )).captured;

    expect(captured[0], 'login');
    expect((captured[1] as Map)['method'], 'google');
  });

  test('logModelFallbackUsed logs event with reason', () async {
    await service.logModelFallbackUsed(reason: 'v2_load_failed');

    final captured = verify(() => analytics.logEvent(
          name: captureAny(named: 'name'),
          parameters: captureAny(named: 'parameters'),
        )).captured;

    expect(captured[0], 'model_fallback_used');
    expect((captured[1] as Map)['reason'], 'v2_load_failed');
  });

  test('event logging never throws when Firebase fails', () async {
    when(() => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenThrow(Exception('analytics down'));

    // Should swallow the error rather than propagate into the user flow.
    await expectLater(
      service.logLowConfidence(confidence: 0.4),
      completes,
    );
  });
}
