import 'dart:developer' as dev;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/di/service_locator.dart';
import '../../firebase_options.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/firestore_service.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../core/utils/notification_helper.dart';
import '../../core/utils/outbreak_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // The background isolate has fresh Dart state. In debug/dev builds we
      // reload .env so AppSecrets can read local overrides. In release builds
      // this is skipped — secrets come from --dart-define / Remote Config.
      if (kDebugMode) {
        try {
          await dotenv.load(fileName: '.env');
        } catch (_) {
          // No .env present — fine, AppSecrets falls back to dart-define.
        }
      }
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      // Idempotent: setupServiceLocator returns early if already registered.
      await setupServiceLocator();
      switch (task) {
        case 'sync_scans':
          return await _syncScansTask();
        case 'treatment_reminder':
          return await _reminderTask(inputData);
        case 'planting_reminder':
          return await _plantingReminderTask(inputData);
        case 'outbreak_alert':
          return await _outbreakAlertTask();
        default:
          return Future.value(true);
      }
    } catch (e) {
      dev.log('Background Task Failed ($task): $e');
      return Future.value(false);
    }
  });
}

Future<bool> _syncScansTask() async {
  try {
    final db = sl<DatabaseHelper>();
    final firestore = sl<FirestoreService>();
    final auth = sl<IAuthRepository>();

    final fbUser = FirebaseAuth.instance.currentUser;
    final userId = auth.currentUser?.id;
    // No authenticated user yet — in a background isolate this is usually the
    // session not having been restored. Return false so WorkManager retries
    // with backoff instead of silently dropping the sync.
    if (userId == null || fbUser == null) return false;

    // Firebase Auth tokens expire after 1 hour. Force a refresh so Firestore
    // writes in a long-delayed background task are not rejected with
    // permission-denied errors. If the refresh fails (revoked session, no
    // network), retry later rather than attempting writes that will be denied.
    try {
      await fbUser.getIdToken(true);
    } catch (e) {
      dev.log('Sync Task: token refresh failed, will retry: $e');
      return false;
    }

    final pending = await db.getAllDetections(userId: userId);
    for (final scan in pending) {
      // Use the local SQLite id as the Firestore document ID so that
      // re-running the task overwrites the same document rather than
      // appending a duplicate on every background wake-up.
      await firestore.upsertScan(
        scan.id.toString(),
        {
          ...scan.toMap(),
          'userId': userId,
          'syncedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    return true;
  } catch (e) {
    dev.log('Sync Task Error: $e');
    return false;
  }
}

Future<bool> _reminderTask(Map<String, dynamic>? inputData) async {
  final diseaseName = inputData?['disease_name'] ?? 'your crop';
  final day = inputData?['reminder_day'] ?? 1;

  String title;
  String body;

  switch (day) {
    case 1:
      title = 'Treatment Reminder - Day 1';
      body = "Don't forget to apply treatment to your $diseaseName today.";
      break;
    case 3:
      title = 'Progress Check - Day 3';
      body = 'Time to check if the treatment for $diseaseName is working.';
      break;
    default:
      title = 'Final Follow-up - Day 7';
      body = "Please re-scan your $diseaseName to confirm it's healthy.";
  }

  await NotificationHelper.showScanReminder(title: title, message: body);

  final db = sl<DatabaseHelper>();
  await db.insertNotification(
    AppNotification(
      id: '',
      title: title,
      body: body,
      type: 'reminder',
      isRead: false,
      createdAt: DateTime.now(),
    ),
  );

  return true;
}

Future<bool> _plantingReminderTask(Map<String, dynamic>? inputData) async {
  final cropType = inputData?['crop_type'] ?? 'your crop';
  final days = inputData?['days'] ?? 7;

  final String title;
  final String body;
  if (days <= 7) {
    title = 'Time to fertilize your $cropType';
    body = 'Apply fertilizer now for healthier $cropType growth.';
  } else if (days <= 30) {
    title = '$cropType Health Check';
    body = 'Scan your $cropType leaves for early disease signs.';
  } else {
    title = 'Harvest window approaching!';
    body = 'Your $cropType planted ~60 days ago may be ready soon.';
  }

  await NotificationHelper.showScanReminder(title: title, message: body);
  return true;
}

Future<bool> _outbreakAlertTask() async {
  try {
    return await OutbreakAlertService.checkAndNotify(
      firestore: sl<FirestoreService>(),
      prefs: sl<SharedPreferences>(),
      db: sl<DatabaseHelper>(),
    );
  } catch (e) {
    dev.log('Outbreak Alert Task Error: $e');
    return false;
  }
}

/// Workmanager is Android-only. All methods are no-ops on other platforms so
/// callers do not need their own platform checks.
class BackgroundTaskHelper {
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  // NOTE: scan-to-cloud sync is performed by the [_syncScansTask] registered
  // from the background outlet (via a one-off task). The periodic sync path
  // is left here for reference but is not currently scheduled at startup.
  // Call this from a user-triggered action (e.g. "Sync now") if needed.
  static Future<void> scheduleSync() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      'sync_task',
      'sync_scans',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> scheduleReminder(
      String diseaseName, int day, Duration delay) async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      'reminder_${diseaseName}_$day',
      'treatment_reminder',
      initialDelay: delay,
      inputData: {
        'disease_name': diseaseName,
        'reminder_day': day,
      },
    );
  }

  /// Periodically checks for outbreaks reported near the user and notifies
  /// them. `keep` policy means re-registering on each launch is a no-op, so
  /// it is safe to call unconditionally at startup.
  static Future<void> scheduleOutbreakAlerts() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      'outbreak_alert_task',
      'outbreak_alert',
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
