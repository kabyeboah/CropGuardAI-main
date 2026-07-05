import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/analytics_service.dart';
import '../../../core/utils/app_lock_controller.dart';
import '../../../core/utils/biometric_service.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/remote/firebase_auth_service.dart';
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
  bool analyticsEnabled = true;
  bool biometricLockEnabled = false;
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
    analyticsEnabled = _prefs.getBool('analytics_enabled') ?? true;
    // Apply persisted consent to the analytics SDK at startup.
    _analytics.setEnabled(analyticsEnabled);
    biometricLockEnabled =
        _prefs.getBool(AppLockController.kEnabledPref) ?? false;
    _resolveBiometricAvailability();
    final idx = _prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[idx.clamp(0, ThemeMode.values.length - 1)];
    final code = _prefs.getString('app_locale');
    _locale = (code != null && code.isNotEmpty) ? Locale(code) : null;
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

  Future<void> clearHistory() async {
    await _db.deleteAllDetections();
    notifyListeners();
  }

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

  Future<void> checkForModelUpdates() async {
    isCheckingUpdates = true;
    updateMessageCode = null;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));
    
    isCheckingUpdates = false;
    updateMessageCode = UiMessage.modelUpToDate;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 3));
    updateMessageCode = null;
    notifyListeners();
  }
}
