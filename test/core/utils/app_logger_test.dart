import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/core/utils/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.setCrashlyticsEnabled(false);
  });

  tearDown(() {
    AppLogger.setCrashlyticsEnabled(false);
  });

  group('AppLogger', () {
    test('consent toggle functions correctly', () {
      AppLogger.setCrashlyticsEnabled(false);
      expect(AppLogger.isCrashlyticsEnabled, isFalse);

      AppLogger.setCrashlyticsEnabled(true);
      expect(AppLogger.isCrashlyticsEnabled, isTrue);
    });

    test('logs debug, info, warning and error without exception', () {
      expect(() => AppLogger.d('Debug test message email=user@knust.edu.gh'), returnsNormally);
      expect(() => AppLogger.i('Info test message token=ghp_1234567890abcdef'), returnsNormally);
      expect(() => AppLogger.w('Warning test message'), returnsNormally);
      expect(() => AppLogger.e('Error test message', Exception('Test failure')), returnsNormally);
    });
  });
}
