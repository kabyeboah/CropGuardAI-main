import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/core/utils/app_logger.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockFirebaseAnalytics analytics;
  late _MockFirebaseCrashlytics crashlytics;
  late AnalyticsService service;

  setUp(() {
    analytics = _MockFirebaseAnalytics();
    crashlytics = _MockFirebaseCrashlytics();

    when(() => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenAnswer((_) async {});

    when(() => analytics.setAnalyticsCollectionEnabled(any()))
        .thenAnswer((_) async {});

    when(() => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});

    when(() => crashlytics.setCrashlyticsCollectionEnabled(any()))
        .thenAnswer((_) async {});

    when(() => crashlytics.setUserIdentifier(any())).thenAnswer((_) async {});

    service = AnalyticsService(analytics, crashlytics);
  });

  tearDown(() {
    AppLogger.setCrashlyticsEnabled(false);
  });

  group('AnalyticsService Consent & Opt-Out', () {
    test('default state is disabled (strict opt-in)', () {
      expect(service.isEnabled, isFalse);
    });

    test('setEnabled(false) disables collection and halts event logging',
        () async {
      await service.setEnabled(false);

      verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
      verify(() => crashlytics.setCrashlyticsCollectionEnabled(false))
          .called(1);
      verify(() => crashlytics.setUserIdentifier('')).called(1);
      expect(AppLogger.isCrashlyticsEnabled, isFalse);

      await service.logScanStarted(source: 'camera');
      await service.setUser(isAnonymous: true);

      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
      verifyNever(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          ));
    });

    test('setEnabled(true) enables collection and allows events', () async {
      await service.setEnabled(true);

      verify(() => analytics.setAnalyticsCollectionEnabled(true)).called(1);
      verify(() => crashlytics.setCrashlyticsCollectionEnabled(true)).called(1);
      expect(AppLogger.isCrashlyticsEnabled, isTrue);

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
      expect(params['confidence'], 87);
      expect(params['is_healthy'], 'false');
    });

    test('sanitizes event parameters (PII and coordinates)', () async {
      await service.setEnabled(true);

      await service.logScanFailed(
          reason: 'Timeout for farmer test@gmail.com at lat=5.603716');

      final captured = verify(() => analytics.logEvent(
            name: captureAny(named: 'name'),
            parameters: captureAny(named: 'parameters'),
          )).captured;

      final params = captured[1] as Map<String, Object>;
      final reason = params['reason'] as String;

      expect(reason.contains('test@gmail.com'), isFalse);
      expect(reason, contains('[REDACTED_EMAIL]'));
      expect(reason, contains('lat=5.60'));
    });
  });

  group('Funnel Events & Resilience', () {
    setUp(() async {
      await service.setEnabled(true);
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

      await expectLater(
        service.logLowConfidence(confidence: 0.4),
        completes,
      );
    });
  });
}
