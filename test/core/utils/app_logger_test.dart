import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/app_logger.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  late _MockFirebaseCrashlytics mockCrashlytics;

  setUp(() {
    mockCrashlytics = _MockFirebaseCrashlytics();
    AppLogger.crashlyticsOverride = mockCrashlytics;
    AppLogger.setCrashlyticsEnabled(false);

    when(() => mockCrashlytics.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
          fatal: any(named: 'fatal'),
          information: any(named: 'information'),
          printDetails: any(named: 'printDetails'),
        )).thenAnswer((_) async {});
  });

  tearDown(() {
    AppLogger.crashlyticsOverride = null;
    AppLogger.setCrashlyticsEnabled(false);
  });

  group('AppLogger', () {
    test('does not report to Crashlytics when consent is disabled (opt-out)',
        () {
      AppLogger.setCrashlyticsEnabled(false);
      AppLogger.e('Some error message with email test@example.com');

      verifyNever(() => mockCrashlytics.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
            fatal: any(named: 'fatal'),
          ));
    });

    test('reports sanitized error to Crashlytics when enabled', () {
      AppLogger.setCrashlyticsEnabled(true);
      AppLogger.e(
        'Upload failed with password=topsecret123 for test@gmail.com',
        Exception('Network failure key=AIzaSyFakeKey1234567890abcdefgh'),
      );

      final captured = verify(() => mockCrashlytics.recordError(
            captureAny(),
            any(),
            reason: captureAny(named: 'reason'),
            fatal: false,
          )).captured;

      final capturedError = captured[0].toString();
      final capturedReason = captured[1] as String;

      expect(
          capturedError.contains('AIzaSyFakeKey1234567890abcdefgh'), isFalse);
      expect(capturedReason.contains('topsecret123'), isFalse);
      expect(capturedReason.contains('test@gmail.com'), isFalse);
      expect(capturedReason, contains('[REDACTED_CREDENTIAL]'));
      expect(capturedReason, contains('[REDACTED_EMAIL]'));
    });
  });
}
