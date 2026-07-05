import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'cropguard_alerts';
  static const String _channelName = 'CropGuard Alerts';
  static const String _channelDesc =
      'Notifications for disease risks and scan reminders';

  // Shared iOS details — a non-null value is required for notifications to
  // appear on iPhone. DarwinNotificationDetails() with no arguments uses the
  // channel defaults (sound on, badge on, alert on).
  static const _iosDetails = DarwinNotificationDetails();

  static Future<void> init() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // DarwinInitializationSettings already carries requestAlertPermission /
    // requestBadgePermission / requestSoundPermission = true, so the system
    // permission dialog is shown when initialize() is called on iOS/macOS.
    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  /// Returns a notification ID that is unique per call so rapid successive
  /// notifications do not overwrite each other in the system tray.
  static int _uniqueId() => DateTime.now().millisecondsSinceEpoch % 100000;

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
  );

  static Future<void> _show({
    required String title,
    required String message,
  }) =>
      _notificationsPlugin.show(
        id: _uniqueId(),
        title: title,
        body: message,
        notificationDetails: _notificationDetails,
      );

  static Future<void> showRiskAlert({
    required String title,
    required String message,
  }) => _show(title: title, message: message);

  static Future<void> showScanReminder({
    required String title,
    required String message,
  }) => _show(title: title, message: message);
}
