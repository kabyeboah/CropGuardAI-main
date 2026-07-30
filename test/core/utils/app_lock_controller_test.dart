import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/utils/app_lock_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppLockController> build({
    required bool enabled,
    Duration grace = const Duration(seconds: 15),
  }) async {
    SharedPreferences.setMockInitialValues(
        enabled ? {AppLockController.kEnabledPref: true} : {});
    final prefs = await SharedPreferences.getInstance();
    return AppLockController(prefs, grace: grace);
  }

  test('locks on cold start when enabled', () async {
    final c = await build(enabled: true);
    expect(c.isLocked, isTrue);
  });

  test('does not lock on cold start when disabled', () async {
    final c = await build(enabled: false);
    expect(c.isLocked, isFalse);
  });

  test('unlock() clears the lock', () async {
    final c = await build(enabled: true);
    c.unlock();
    expect(c.isLocked, isFalse);
  });

  test('a quick pause/resume (within grace) does not re-lock', () async {
    final c = await build(enabled: true);
    c.unlock();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.isLocked, isFalse);
  });

  test('a quick inactive/resume (within grace) does not re-lock', () async {
    final c = await build(enabled: true);
    c.unlock();
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.isLocked, isFalse);
  });

  test('resuming from inactive state after grace period locks the app', () async {
    final c = await build(enabled: true, grace: Duration.zero);
    c.unlock();
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future.delayed(const Duration(milliseconds: 1));
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.isLocked, isTrue);
  });

  test('resuming from paused state after grace period locks the app', () async {
    final c = await build(enabled: true, grace: Duration.zero);
    c.unlock();
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future.delayed(const Duration(milliseconds: 1));
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.isLocked, isTrue);
  });

  test('disabling while locked clears the lock', () async {
    final c = await build(enabled: true);
    expect(c.isLocked, isTrue);
    c.setEnabled(false);
    expect(c.isLocked, isFalse);
  });

  test('lifecycle changes are ignored when disabled', () async {
    final c = await build(enabled: false);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.isLocked, isFalse);
  });
}
