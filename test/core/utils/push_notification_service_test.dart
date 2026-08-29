import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService', () {
    test('syncFcmToken completes safely when unauthenticated or offline', () async {
      // Calling syncFcmToken without Firebase initialized should gracefully catch exceptions
      // and log warnings instead of crashing the application or throwing unhandled errors.
      await expectLater(
        PushNotificationService.syncFcmToken('test-user-123'),
        completes,
      );
    });

    test('syncFcmToken completes safely when no userId is passed', () async {
      await expectLater(
        PushNotificationService.syncFcmToken(),
        completes,
      );
    });
  });
}
