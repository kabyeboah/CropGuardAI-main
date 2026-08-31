import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/core/utils/app_lock_controller.dart';
import 'package:cropguard_flutter/core/utils/biometric_service.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/presentation/screens/settings/settings_provider.dart';

class _MockAuth extends Mock implements FirebaseAuthService {}

class _MockDb extends Mock implements DatabaseHelper {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBiometric extends Mock implements BiometricService {}

class _MockAppLock extends Mock implements AppLockController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuth auth;
  late _MockDb db;
  late _MockAnalytics analytics;
  late _MockBiometric biometric;
  late _MockAppLock appLock;

  setUp(() {
    auth = _MockAuth();
    db = _MockDb();
    analytics = _MockAnalytics();
    biometric = _MockBiometric();
    appLock = _MockAppLock();
    when(() => analytics.setEnabled(any())).thenAnswer((_) async {});
    when(() => biometric.isAvailable()).thenAnswer((_) async => false);
  });

  Future<SettingsProvider> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsProvider(prefs, auth, db, analytics, biometric, appLock);
  }

  test('defaults to system locale (null) when nothing persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await build();
    expect(provider.locale, isNull);
  });

  test('loads a persisted locale on construction', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'tw'});
    final provider = await build();
    expect(provider.locale, const Locale('tw'));
  });

  test('setLocale persists the chosen language', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await build();

    provider.setLocale('ee');
    expect(provider.locale, const Locale('ee'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'ee');
  });

  test('setLocale(null) clears the override back to system', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'dag'});
    final provider = await build();
    expect(provider.locale, const Locale('dag'));

    provider.setLocale(null);
    expect(provider.locale, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), isNull);
  });

  test('supportedLanguages covers en, tw, ee, dag', () {
    expect(SettingsProvider.supportedLanguages.keys,
        containsAll(['en', 'tw', 'ee', 'dag']));
  });

  test('modelVersionLabel initializes with default or metadata version',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await build();
    expect(provider.modelVersionLabel, contains('51 classes'));
  });

  test('checkForModelUpdates toggles state and resolves updateMessageCode',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await build();

    expect(provider.isCheckingUpdates, isFalse);
    expect(provider.updateMessageCode, isNull);

    final future = provider.checkForModelUpdates();
    expect(provider.isCheckingUpdates, isTrue);

    await future;
    expect(provider.isCheckingUpdates, isFalse);
    expect(provider.updateMessageCode, isNotNull);
  });
}
