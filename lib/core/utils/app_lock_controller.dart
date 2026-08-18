import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';

/// Drives the biometric app-lock. Used as the GoRouter `refreshListenable` so
/// the router re-evaluates its redirect whenever the lock state changes.
///
/// When enabled (Settings → biometric lock), the app is locked on cold start and
/// re-locks when resuming from background after [_grace]. Firebase keeps the
/// user signed in; this only gates UI access.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  final AnalyticsService? _analytics;

  AppLockController(
    this._prefs, {
    Duration grace = const Duration(seconds: 15),
    AnalyticsService? analytics,
  })  : _grace = grace,
        _analytics = analytics {
    _enabled = _prefs.getBool(kEnabledPref) ?? false;
    _isLocked = _enabled; // require an unlock on cold start when enabled
  }

  static const String kEnabledPref = 'biometric_lock_enabled';

  /// Grace period so quickly switching apps (or the biometric prompt itself
  /// briefly backgrounding us) doesn't force a re-lock.
  final Duration _grace;

  final SharedPreferences _prefs;
  bool _enabled = false;
  bool _isLocked = false;
  bool _authenticating = false;
  DateTime? _pausedAt;

  bool get isLocked => _isLocked;
  bool get enabled => _enabled;

  /// Register the lifecycle observer (call once at startup).
  void start() => WidgetsBinding.instance.addObserver(this);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Kept in sync by SettingsProvider when the user toggles the setting.
  /// Turning it on does not lock immediately (the user is already in-app); it
  /// takes effect on the next launch/resume. Turning it off clears any lock.
  void setEnabled(bool value) {
    _enabled = value;
    if (!value && _isLocked) {
      _isLocked = false;
      notifyListeners();
    }
  }

  /// Suppress lifecycle-driven locking while the biometric prompt is showing
  /// (the OS backgrounds us during the prompt on some platforms).
  void markAuthenticating(bool value) => _authenticating = value;

  void unlock() {
    if (!_isLocked) return;
    _isLocked = false;
    _pausedAt = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || _authenticating) return;
    if (state != AppLifecycleState.resumed) {
      _pausedAt ??= DateTime.now();
    } else {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (!_isLocked &&
          pausedAt != null &&
          DateTime.now().difference(pausedAt) > _grace) {
        _isLocked = true;
        unawaited(_analytics?.logAppLockTriggered());
        notifyListeners();
      }
    }
  }
}
