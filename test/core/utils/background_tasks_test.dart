import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropguard_flutter/core/di/service_locator.dart';
import 'package:cropguard_flutter/core/utils/background_tasks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> registeredOneOffTasks = [];
  final List<String> registeredPeriodicTasks = [];
  final List<String> cancelledTasks = [];

  setUp(() async {
    registeredOneOffTasks.clear();
    registeredPeriodicTasks.clear();
    cancelledTasks.clear();

    if (sl.isRegistered<SharedPreferences>()) {
      await sl.unregister<SharedPreferences>();
    }
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(prefs);

    BackgroundTaskHelper.isAndroidOverride = true;

    BackgroundTaskHelper.registerOneOffTaskFn = (
      uniqueName,
      taskName, {
      existingWorkPolicy,
      initialDelay,
      constraints,
      inputData,
    }) async {
      registeredOneOffTasks.add('$uniqueName:$taskName');
    };

    BackgroundTaskHelper.registerPeriodicTaskFn = (
      uniqueName,
      taskName, {
      frequency,
      existingWorkPolicy,
      initialDelay,
      constraints,
      inputData,
    }) async {
      registeredPeriodicTasks.add(uniqueName);
    };

    BackgroundTaskHelper.cancelByUniqueNameFn = (uniqueName) async {
      cancelledTasks.add(uniqueName);
    };
  });

  test('scheduleSync registers one-off sync_scans task on Android', () async {
    await BackgroundTaskHelper.scheduleSync();
    expect(registeredOneOffTasks.contains('sync_task:sync_scans'), isTrue);
  });

  test('scheduleSync is no-op when isAndroidOverride is false', () async {
    BackgroundTaskHelper.isAndroidOverride = false;
    await BackgroundTaskHelper.scheduleSync();
    expect(registeredOneOffTasks.isEmpty, isTrue);
  });

  test('scheduleReminder registers one-off treatment_reminder task', () async {
    await BackgroundTaskHelper.scheduleReminder(
        'Cassava Mosaic', 3, const Duration(days: 3));
    expect(
        registeredOneOffTasks
            .contains('reminder_Cassava Mosaic_3:treatment_reminder'),
        isTrue);
  });

  test('scheduleOutbreakAlerts registers periodic task and sets preference',
      () async {
    await BackgroundTaskHelper.scheduleOutbreakAlerts();

    expect(registeredPeriodicTasks.contains('outbreak_alert_task'), isTrue);

    final prefs = sl<SharedPreferences>();
    expect(prefs.getBool('outbreak_alerts_scheduled'), isTrue);
  });

  test('scheduleOutbreakAlerts does not re-register if already scheduled',
      () async {
    final prefs = sl<SharedPreferences>();
    await prefs.setBool('outbreak_alerts_scheduled', true);

    await BackgroundTaskHelper.scheduleOutbreakAlerts();

    expect(registeredPeriodicTasks.contains('outbreak_alert_task'), isFalse);
  });

  test(
      'scheduleOutbreakAlerts cancels alerts if notifications are disabled in settings',
      () async {
    final prefs = sl<SharedPreferences>();
    await prefs.setBool('notifications_enabled', false);
    await prefs.setBool('outbreak_alerts_scheduled', true);

    await BackgroundTaskHelper.scheduleOutbreakAlerts();

    expect(cancelledTasks.contains('outbreak_alert_task'), isTrue);
    expect(prefs.getBool('outbreak_alerts_scheduled'), isFalse);
  });

  test('cancelOutbreakAlerts cancels the task and updates preference',
      () async {
    final prefs = sl<SharedPreferences>();
    await prefs.setBool('outbreak_alerts_scheduled', true);

    await BackgroundTaskHelper.cancelOutbreakAlerts();

    expect(cancelledTasks.contains('outbreak_alert_task'), isTrue);
    expect(prefs.getBool('outbreak_alerts_scheduled'), isFalse);
  });

  // ─── iOS BGAppRefreshTask ──────────────────────────────────────────────────

  test('kIosBgTaskId matches the declared Info.plist identifier', () {
    expect(BackgroundTaskHelper.kIosBgTaskId, 'com.cropguard.ai.sync');
  });

  test(
      'scheduleIosBGAppRefresh is a no-op on non-iOS (MissingPluginException swallowed)',
      () async {
    await expectLater(
      BackgroundTaskHelper.scheduleIosBGAppRefresh(),
      completes,
    );
  });

  test('scheduleIosForegroundSync completes safely without errors', () async {
    await expectLater(
      BackgroundTaskHelper.scheduleIosForegroundSync(),
      completes,
    );
  });
}
