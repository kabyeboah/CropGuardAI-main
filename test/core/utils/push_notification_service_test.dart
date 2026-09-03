import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService', () {
    test('syncFcmToken completes safely when unauthenticated or offline',
        () async {
      await expectLater(
        PushNotificationService.syncFcmToken('test-user-123'),
        completes,
      );
    });

    test('clearFcmToken completes safely when unauthenticated or offline',
        () async {
      await expectLater(
        PushNotificationService.clearFcmToken('test-user-123'),
        completes,
      );
    });

    test('clearFcmToken completes safely when no userId is passed', () async {
      await expectLater(
        PushNotificationService.clearFcmToken(),
        completes,
      );
    });

    test('handleMessageClick routes to specified payload route', () {
      String? tappedRoute;
      PushNotificationService.setOnNotificationTapForTesting((route) {
        tappedRoute = route;
      });

      const message = AlertMessage(
        data: {'route': '/treatment_tracker', 'type': 'reminder'},
      );

      PushNotificationService.handleMessageClickForTesting(message);
      expect(tappedRoute, '/treatment_tracker');
    });

    test('handleMessageClick falls back to /outbreak_map when route is missing',
        () {
      String? tappedRoute;
      PushNotificationService.setOnNotificationTapForTesting((route) {
        tappedRoute = route;
      });

      const message = AlertMessage(
        data: {'type': 'outbreak_alert'},
      );

      PushNotificationService.handleMessageClickForTesting(message);
      expect(tappedRoute, '/outbreak_map');
    });

    test(
        'handleForegroundMessage executes without uncaught errors on outbreak alert',
        () async {
      const message = AlertMessage(
        messageId: 'msg-test-123',
        data: {
          'title': 'High Risk: Cocoa Swollen Shoot',
          'body': 'Severe outbreak detected in Eastern Region.',
          'type': 'outbreak_alert',
        },
      );

      await expectLater(
        PushNotificationService.handleForegroundMessageForTesting(message),
        completes,
      );
    });

    test(
        'handleForegroundMessage executes without uncaught errors on scan reminder',
        () async {
      const message = AlertMessage(
        messageId: 'msg-test-456',
        data: {
          'title': 'Scan Follow-up',
          'body': 'Check your cassava leaves today.',
          'type': 'scan_reminder',
        },
      );

      await expectLater(
        PushNotificationService.handleForegroundMessageForTesting(message),
        completes,
      );
    });
  });
}
