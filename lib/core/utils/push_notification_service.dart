import 'dart:async';
import 'package:flutter/foundation.dart';

import '../di/service_locator.dart';
import '../../data/local/database_helper.dart';
import '../../domain/models/app_notification.dart';
import 'app_logger.dart';
import 'notification_helper.dart';

/// Notification payload model for push and realtime outbreak alerts.
class AlertMessage {
  final String? messageId;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const AlertMessage({
    this.messageId,
    this.title,
    this.body,
    this.data = const {},
  });
}

/// Push and alert service handling local notification display and deep-link routing.
class PushNotificationService {
  /// Callback when user taps an alert notification payload
  static void Function(String? payload)? _onNotificationTap;

  static Future<void> init(
      {void Function(String? payload)? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;
    AppLogger.d('PushNotificationService initialized');
  }

  /// No-op sync token for backward compatibility
  static Future<void> syncFcmToken([String? userId]) async {
    AppLogger.d('PushNotificationService: background alerts active');
  }

  /// No-op clear token on logout
  static Future<void> clearFcmToken([String? userId]) async {
    AppLogger.d('PushNotificationService: clear tokens completed');
  }

  static Future<void> handleForegroundAlert(AlertMessage message) async {
    AppLogger.d('Foreground alert received: ${message.data}');

    final title = message.title ?? message.data['title']?.toString() ?? 'Disease Alert';
    final body = message.body ??
        message.data['body']?.toString() ??
        'A new risk update is available for your region.';
    final type = message.data['type']?.toString() ?? 'outbreak_alert';

    // Show local notification banner
    if (type == 'outbreak_alert' || type == 'risk_alert') {
      await NotificationHelper.showRiskAlert(title: title, message: body);
    } else {
      await NotificationHelper.showScanReminder(title: title, message: body);
    }

    // Insert into local SQLite inbox
    try {
      if (sl.isRegistered<DatabaseHelper>()) {
        final db = sl<DatabaseHelper>();
        await db.insertNotification(
          AppNotification(
            id: message.messageId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            body: body,
            type: type,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      AppLogger.w('Failed to save notification to local DB: $e');
    }
  }

  static void handleAlertClick(AlertMessage message) {
    AppLogger.d('Alert notification clicked: ${message.data}');
    final route = message.data['route']?.toString() ?? '/outbreak_map';
    _onNotificationTap?.call(route);
  }

  @visibleForTesting
  static Future<void> handleForegroundMessageForTesting(
          AlertMessage message) =>
      handleForegroundAlert(message);

  @visibleForTesting
  static void handleMessageClickForTesting(AlertMessage message) =>
      handleAlertClick(message);

  @visibleForTesting
  static void setOnNotificationTapForTesting(
      void Function(String? payload)? callback) {
    _onNotificationTap = callback;
  }
}
