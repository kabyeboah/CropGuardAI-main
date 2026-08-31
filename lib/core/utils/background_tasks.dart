import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/di/service_locator.dart';
import '../../firebase_options.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/firestore_service.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/notification_helper.dart';
import '../../core/utils/outbreak_alert_service.dart';
import '../../domain/repositories/i_community_repository.dart';
import '../../data/repositories/community_repository_impl.dart';
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

      final Future<bool> taskFuture;
      switch (task) {
        case 'sync_scans':
          taskFuture = _syncScansTask();
          break;
        case 'treatment_reminder':
          taskFuture = _reminderTask(inputData);
          break;
        case 'planting_reminder':
          taskFuture = _plantingReminderTask(inputData);
          break;
        case 'outbreak_alert':
          taskFuture = _outbreakAlertTask();
          break;
        default:
          taskFuture = Future.value(true);
      }

      // Max execution time of 2 minutes to prevent wakelock leaks
      return await taskFuture.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          AppLogger.w(
              'Background Task ($task) timed out. Completing to prevent wakelock leak.');
          return false;
        },
      );
    } catch (e) {
      AppLogger.w('Background Task Failed ($task): $e');
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
      AppLogger.w('Sync Task: token refresh failed, will retry: $e');
      return false;
    }

    final pending = await db.getUnsyncedDetections(userId: userId);
    if (pending.isEmpty) {
      AppLogger.d('Sync Task: No unsynced scans found.');
      return true;
    }

    final syncedIds = <int>[];
    for (final scan in pending) {
      try {
        // Use the local SQLite id as the Firestore document ID so that
        // re-running the task overwrites the same document rather than
        // appending a duplicate on every background wake-up.
        await firestore.upsertScan(
          scan.id.toString(),
          {
            ...scan.toMap(),
            'userId': userId,
            'syncedAt': FieldValue.serverTimestamp(),
            'isSynced': 1,
          },
        );
        syncedIds.add(scan.id);
      } catch (e) {
        AppLogger.w('Sync Task: failed to sync scan ${scan.id}: $e');
      }
    }

    if (syncedIds.isNotEmpty) {
      await db.markDetectionsSynced(syncedIds);
    }

    return syncedIds.length == pending.length;
  } catch (e) {
    AppLogger.e('Sync Task Error: $e');
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
    AppLogger.e('Outbreak Alert Task Error: $e');
    return false;
  }
}

/// Workmanager is Android-only. All methods are no-ops on other platforms so
/// callers do not need their own platform checks.
class BackgroundTaskHelper {
  static bool isAndroidOverride = Platform.isAndroid;

  /// BGTaskScheduler identifier — must match Info.plist and AppDelegate.swift.
  static const String kIosBgTaskId = 'com.cropguard.ai.sync';

  /// Method channel shared with the native iOS BGAppRefreshTask handler.
  static const MethodChannel _iosBgChannel =
      MethodChannel('com.cropguard.ai/bg_sync');

  static Future<void> Function(
    String uniqueName,
    String taskName, {
    ExistingWorkPolicy? existingWorkPolicy,
    Duration? initialDelay,
    Constraints? constraints,
    Map<String, dynamic>? inputData,
  }) registerOneOffTaskFn = Workmanager().registerOneOffTask;

  static Future<void> Function(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    Duration? initialDelay,
    Constraints? constraints,
    Map<String, dynamic>? inputData,
  }) registerPeriodicTaskFn = Workmanager().registerPeriodicTask;

  static Future<void> Function(String uniqueName) cancelByUniqueNameFn =
      Workmanager().cancelByUniqueName;

  static Future<void> init() async {
    if (isAndroidOverride) {
      await Workmanager().initialize(
        callbackDispatcher,
      );
    } else if (Platform.isIOS) {
      // Register the Dart-side handler that the native BGAppRefreshTask fires
      // via method channel, then schedule the first OS-level wake-up.
      _registerIosTriggerSyncHandler();
      await scheduleIosBGAppRefresh();
      // Also drain immediately on foreground return (belt-and-suspenders).
      unawaited(scheduleIosForegroundSync());
    }
  }

  /// Registers the method-channel handler that the Swift AppDelegate calls
  /// when the OS fires a BGAppRefreshTask for this app.
  ///
  /// The handler drains PendingSyncQueue and returns `true` on success so
  /// BGTaskScheduler can call `setTaskCompleted(success: true)`.
  static void _registerIosTriggerSyncHandler() {
    _iosBgChannel.setMethodCallHandler((call) async {
      if (call.method != 'triggerSync') return null;
      try {
        final repo = sl<ICommunityRepository>();
        if (repo is CommunityRepositoryImpl) {
          await repo.drainPendingSync();
        }
        AppLogger.d('iOS BGAppRefreshTask sync drain completed.');
        return true;
      } catch (e) {
        AppLogger.w('iOS BGAppRefreshTask sync drain failed: $e');
        return false;
      }
    });
  }

  /// Asks native iOS to schedule the next BGAppRefreshTask wake-up.
  /// Safe to call multiple times — the native layer deduplicates by task ID.
  static Future<void> scheduleIosBGAppRefresh() async {
    if (!Platform.isIOS) return;
    try {
      await _iosBgChannel.invokeMethod<void>('scheduleBGSync');
    } on MissingPluginException {
      // Unit test environment — no plugin registered. Ignored.
    } catch (e) {
      AppLogger.w('scheduleIosBGAppRefresh failed: $e');
    }
  }

  /// Triggers an immediate offline queue drain when returning to foreground on iOS.
  static Future<void> scheduleIosForegroundSync() async {
    if (!Platform.isIOS) return;
    try {
      final repo = sl<ICommunityRepository>();
      if (repo is CommunityRepositoryImpl) {
        await repo.drainPendingSync();
      }
    } catch (e) {
      AppLogger.w('iOS foreground sync drain skipped/failed: $e');
    }
  }

  // NOTE: scan-to-cloud sync is performed by the [_syncScansTask] registered
  // from the background outlet (via a one-off task). The periodic sync path
  // is left here for reference but is not currently scheduled at startup.
  // Call this from a user-triggered action (e.g. "Sync now") if needed.
  static Future<void> scheduleSync() async {
    if (!isAndroidOverride) return;
    await registerOneOffTaskFn(
      'sync_task',
      'sync_scans',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> scheduleReminder(
      String diseaseName, int day, Duration delay) async {
    if (!isAndroidOverride) return;
    await registerOneOffTaskFn(
      'reminder_${diseaseName}_$day',
      'treatment_reminder',
      existingWorkPolicy: ExistingWorkPolicy.keep,
      initialDelay: delay,
      inputData: {
        'disease_name': diseaseName,
        'reminder_day': day,
      },
    );
  }

  /// Periodically checks for outbreaks reported near the user and notifies
  /// them. We verify SharedPreferences to prevent duplicate registration overhead on every launch.
  static Future<void> scheduleOutbreakAlerts() async {
    if (!isAndroidOverride) return;
    final prefs = sl<SharedPreferences>();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) {
      await cancelOutbreakAlerts();
      return;
    }
    if (prefs.getBool('outbreak_alerts_scheduled') == true) {
      return;
    }
    await registerPeriodicTaskFn(
      'outbreak_alert_task',
      'outbreak_alert',
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true, // respects battery optimizations
      ),
    );
    await prefs.setBool('outbreak_alerts_scheduled', true);
  }

  static Future<void> cancelOutbreakAlerts() async {
    if (!isAndroidOverride) return;
    await cancelByUniqueNameFn('outbreak_alert_task');
    final prefs = sl<SharedPreferences>();
    await prefs.setBool('outbreak_alerts_scheduled', false);
  }
}
