import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/analytics_service.dart';
import '../../../core/utils/app_lock_controller.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/background_tasks.dart';
import '../../../core/utils/biometric_service.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../data/remote/firestore_service.dart';
import '../../l10n/ui_message.dart';

/// Equivalent of SettingsViewModel.kt
class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FirebaseAuthService _auth;
  final DatabaseHelper _db;
  final AnalyticsService _analytics;
  final BiometricService _biometric;
  final AppLockController _appLock;

  SettingsProvider(
    this._prefs,
    this._auth,
    this._db,
    this._analytics,
    this._biometric,
    this._appLock,
  ) {
    _load();
    _loadAppVersion();
  }

  String appVersionLabel = 'CropGuard AI';

  bool largeTextMode = false;
  bool showConfidence = true;
  bool analyticsEnabled = false; // Task 0.13: Default to opt-in (false until user explicitly enables)
  bool biometricLockEnabled = false;
  bool notificationsEnabled = true;
  // Whether the device can do biometric / device-credential auth — gates the
  // visibility of the toggle. Resolved asynchronously at startup.
  bool biometricAvailable = false;
  UiMessage? deleteErrorCode;
  bool isDeleting = false;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Languages the UI can render. `null` locale means "follow system".
  /// Twi (tw), Ewe (ee) and Dagbani (dag) fall back to English for any string
  /// not yet professionally translated (see l10n/app_*.arb).
  static const supportedLanguages = <String, String>{
    'en': 'English',
    'tw': 'Twi (Akan)',
    'ee': 'Ewe',
    'dag': 'Dagbani',
  };

  Locale? _locale;
  Locale? get locale => _locale;

  void _load() {
    largeTextMode = _prefs.getBool('large_text_mode') ?? false;
    showConfidence = _prefs.getBool('show_confidence') ?? true;
    analyticsEnabled = _prefs.getBool('analytics_enabled') ?? false;
    // Apply persisted consent to the analytics SDK at startup.
    _analytics.setEnabled(analyticsEnabled);
    biometricLockEnabled =
        _prefs.getBool(AppLockController.kEnabledPref) ?? false;
    _resolveBiometricAvailability();
    final idx = _prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[idx.clamp(0, ThemeMode.values.length - 1)];
    final code = _prefs.getString('app_locale');
    _locale = (code != null && code.isNotEmpty) ? Locale(code) : null;
    notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    notifyListeners();
  }

  /// Pass `null` to follow the system language.
  void setLocale(String? code) {
    if (code == null || code.isEmpty) {
      _locale = null;
      _prefs.remove('app_locale');
    } else {
      _locale = Locale(code);
      _prefs.setString('app_locale', code);
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersionLabel = 'CropGuard AI v${info.version} (${info.buildNumber})';
      notifyListeners();
    } catch (_) {
      appVersionLabel = 'CropGuard AI v1.0.0';
      notifyListeners();
    }
  }

  void setLargeTextMode(bool v) {
    largeTextMode = v;
    _prefs.setBool('large_text_mode', v);
    notifyListeners();
  }

  void setShowConfidence(bool v) {
    showConfidence = v;
    _prefs.setBool('show_confidence', v);
    notifyListeners();
  }

  void setAnalyticsEnabled(bool v) {
    analyticsEnabled = v;
    _prefs.setBool('analytics_enabled', v);
    _analytics.setEnabled(v);
    notifyListeners();
  }

  Future<void> _resolveBiometricAvailability() async {
    biometricAvailable = await _biometric.isAvailable();
    notifyListeners();
  }

  void setBiometricLockEnabled(bool v) {
    biometricLockEnabled = v;
    _prefs.setBool(AppLockController.kEnabledPref, v);
    _appLock.setEnabled(v);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool v) async {
    if (v) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        notificationsEnabled = true;
        await _prefs.setBool('notifications_enabled', true);
        await BackgroundTaskHelper.scheduleOutbreakAlerts();
      } else {
        notificationsEnabled = false;
        await _prefs.setBool('notifications_enabled', false);
        await BackgroundTaskHelper.cancelOutbreakAlerts();
      }
    } else {
      notificationsEnabled = false;
      await _prefs.setBool('notifications_enabled', false);
      await BackgroundTaskHelper.cancelOutbreakAlerts();
    }
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _db.deleteAllDetections();
    notifyListeners();
  }

  /// Task 0.10: Clean up local scan images stored on device.
  Future<int> clearLocalScanImages() async {
    int deletedCount = 0;
    try {
      final detections = await _db.getAllDetections();
      for (final d in detections) {
        if (d.imagePath.isNotEmpty) {
          final file = File(d.imagePath);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        }
      }
    } catch (e) {
      AppLogger.w('SettingsProvider: clearLocalScanImages failed: $e');
    }
    notifyListeners();
    return deletedCount;
  }

  /// Task 0.4: Account deletion must purge data prior to Auth deletion.
  Future<void> deleteAccount({
    required VoidCallback onSuccess,
    String? password,
    bool reauthWithGoogle = false,
  }) async {
    isDeleting = true;
    deleteErrorCode = null;
    notifyListeners();
    try {
      if (reauthWithGoogle) {
        await _auth.reauthenticateWithGoogle();
      } else if (password != null && password.isNotEmpty) {
        await _auth.reauthenticateWithPassword(password);
      } else if (_auth.hasPasswordProvider) {
        throw Exception('Password required');
      } else if (_auth.hasGoogleProvider) {
        throw Exception('Google sign-in required');
      }

      // Purge cloud user documents while still authenticated
      final uid = _auth.currentUserId;
      if (uid.isNotEmpty) {
        await sl<FirestoreService>().deleteUserData(uid);
      }

      // Purge local detections for this user
      await clearHistory();

      await _auth.deleteAccount();
      isDeleting = false;
      notifyListeners();
      onSuccess();
    } catch (e) {
      isDeleting = false;
      final msg = e.toString();
      if (msg.contains('requires-recent-login') ||
          msg.contains('Password required') ||
          msg.contains('Google sign-in required')) {
        deleteErrorCode = UiMessage.deleteAccountReauth;
      } else {
        deleteErrorCode = UiMessage.deleteAccountFailed;
      }
      notifyListeners();
    }
  }

  bool isCheckingUpdates = false;
  UiMessage? updateMessageCode;

  /// Task 0.3: Honestly compare local model_metadata.json against Remote Config.
  Future<void> checkForModelUpdates() async {
    isCheckingUpdates = true;
    updateMessageCode = null;
    notifyListeners();

    try {
      final jsonStr = await rootBundle.loadString('assets/model_metadata.json');
      final metadata = jsonDecode(jsonStr) as Map<String, dynamic>;
      final localVersion = metadata['version']?.toString() ?? '1.0';

      String remoteVersion = localVersion;
      try {
        final rc = FirebaseRemoteConfig.instance;
        await rc.fetchAndActivate().timeout(const Duration(seconds: 4));
        final val = rc.getString('latest_model_version');
        if (val.isNotEmpty) remoteVersion = val;
      } catch (_) {}

      isCheckingUpdates = false;
      if (remoteVersion != localVersion && _isVersionHigher(remoteVersion, localVersion)) {
        updateMessageCode = UiMessage((l) => 'New model v$remoteVersion available!');
      } else {
        updateMessageCode = UiMessage.modelUpToDate;
      }
      notifyListeners();
    } catch (_) {
      isCheckingUpdates = false;
      updateMessageCode = UiMessage.modelUpToDate;
      notifyListeners();
    }

    await Future.delayed(const Duration(seconds: 3));
    updateMessageCode = null;
    notifyListeners();
  }

  bool _isVersionHigher(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map(int.parse).toList();
      final parts2 = v2.split('.').map(int.parse).toList();
      for (var i = 0; i < math.max(parts1.length, parts2.length); i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        if (p1 > p2) return true;
        if (p1 < p2) return false;
      }
    } catch (_) {}
    return false;
  }
}
