import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../di/service_locator.dart';
import '../../data/local/database_helper.dart';
import '../../domain/models/app_notification.dart';
import 'app_logger.dart';
import 'notification_helper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    AppLogger.d('FCM Background Message received: ${message.messageId}');
  } catch (e) {
    AppLogger.e('Error handling FCM background message', e);
  }
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Callback when user taps a push notification payload
  static void Function(String? payload)? _onNotificationTap;

  static Future<void> init({void Function(String? payload)? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (critical for iOS and Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AppLogger.d('FCM Authorization status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Subscribe to global outbreak alerts topic for broadcast notifications
      await _subscribeToTopic('outbreak_alerts');

      // Fetch and register current device FCM Token
      await _syncFcmToken();

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToFirestore(newToken);
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Notification click when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      // Check if app was launched directly from a terminated notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageClick(initialMessage);
      }
    }
  }

  static Future<void> _subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      AppLogger.d('Subscribed to FCM topic: $topic');
    } catch (e) {
      AppLogger.w('Failed to subscribe to FCM topic $topic: $e');
    }
  }

  static Future<void> _syncFcmToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        AppLogger.d('FCM Token retrieved: ${token.substring(0, 8)}...');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      AppLogger.w('Failed to get FCM token: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));
      AppLogger.d('FCM Token synced to Firestore for user ${user.uid}');
    } catch (e) {
      AppLogger.w('Failed to save FCM token to Firestore: $e');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.d('FCM Foreground message received: ${message.data}');

    final title = message.notification?.title ?? message.data['title'] ?? 'Disease Alert';
    final body = message.notification?.body ?? message.data['body'] ?? 'A new risk update is available for your region.';
    final type = message.data['type'] ?? 'outbreak_alert';

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
            id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            body: body,
            type: type,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      AppLogger.w('Failed to save push notification to local DB: $e');
    }
  }

  static void _handleMessageClick(RemoteMessage message) {
    AppLogger.d('FCM Push notification clicked: ${message.data}');
    final route = message.data['route'] ?? '/outbreak_map';
    _onNotificationTap?.call(route);
  }
}
