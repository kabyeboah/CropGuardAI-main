import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/core/utils/app_logger.dart';

void main() {
  late AnalyticsService service;

  setUp(() {
    service = AnalyticsService();
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
      expect(service.isEnabled, isFalse);
      expect(AppLogger.isCrashlyticsEnabled, isFalse);

      await service.logScanStarted(source: 'camera');
      await service.setUser(isAnonymous: true);

      expect(service.recordedEvents, isEmpty);
    });

    test('setEnabled(true) enables collection and allows events', () async {
      await service.setEnabled(true);
      expect(service.isEnabled, isTrue);
      expect(AppLogger.isCrashlyticsEnabled, isTrue);

      await service.logScanCompleted(
        disease: 'Tomato___Late_blight',
        confidence: 0.873,
        isHealthy: false,
      );

      expect(service.recordedEvents.length, 1);
      final event = service.recordedEvents.first;
      expect(event['name'], 'scan_completed');
      final params = event['params'] as Map<String, dynamic>;
      expect(params['disease'], 'Tomato___Late_blight');
      expect(params['confidence'], 87);
      expect(params['is_healthy'], 'false');
    });

    test('sanitizes event parameters (PII and coordinates)', () async {
      await service.setEnabled(true);

      await service.logScanFailed(
        reason: 'Failed for user admin@cropguard.org with key=AIzaSyFakeKey123',
      );

      final event = service.recordedEvents.first;
      final params = event['params'] as Map<String, dynamic>;
      final reason = params['reason'] as String;

      expect(reason.contains('admin@cropguard.org'), isFalse);
      expect(reason.contains('AIzaSyFakeKey123'), isFalse);
      expect(reason, contains('[REDACTED_EMAIL]'));
      expect(reason, contains('[REDACTED_CREDENTIAL]'));
    });
  });
}
