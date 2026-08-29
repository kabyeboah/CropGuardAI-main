import 'dart:math' as math;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_secrets.dart';
import 'app_logger.dart';

class VersionCheckService {
  VersionCheckService._();

  /// Checks if the installed app version falls below the `min_required_app_version`
  /// configured in Firebase Remote Config. Returns `true` if an update is mandatory.
  static Future<bool> isUpdateRequired() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate().timeout(const Duration(seconds: 4));
      final minRequiredVersion = rc.getString('min_required_app_version');

      if (minRequiredVersion.isEmpty) return false;
      return _isVersionLower(currentVersion, minRequiredVersion);
    } catch (e) {
      AppLogger.w('VersionCheckService: check failed ($e)');
      return false;
    }
  }

  /// Checks if a newer model version is published in Firebase Remote Config.
  /// Compares bundled model version [currentVersion] against Remote Config parameter `latest_model_version`.
  static Future<bool> isModelUpdateAvailable(String currentVersion) async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate().timeout(const Duration(seconds: 4));
      final latestModelVersion = rc.getString('latest_model_version');

      if (latestModelVersion.isEmpty) return false;
      return _isVersionLower(currentVersion, latestModelVersion);
    } catch (e) {
      AppLogger.w('VersionCheckService: model update check failed ($e)');
      return false;
    }
  }

  /// Returns the platform-appropriate store URL for the app based on [defaultTargetPlatform] (or given [platform]).
  static Uri getStoreUri([TargetPlatform? platform]) {
    final target = platform ?? defaultTargetPlatform;
    final isIos = target == TargetPlatform.iOS;
    final url = isIos
        ? 'https://apps.apple.com/app/${AppSecrets.iosBundleId}'
        : 'https://play.google.com/store/apps/details?id=${AppSecrets.androidPackageName}';
    return Uri.parse(url);
  }

  /// Opens the store listing for updating the app.
  static Future<bool> launchStoreUrl([TargetPlatform? platform]) async {
    try {
      final uri = getStoreUri(platform);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri);
      }
    } catch (e) {
      AppLogger.e('VersionCheckService: failed to launch store url ($e)');
      return false;
    }
  }

  static bool _isVersionLower(String current, String required) {
    try {
      final partsCurrent = current.split('.').map(int.parse).toList();
      final partsRequired = required.split('.').map(int.parse).toList();
      final maxLen = math.max(partsCurrent.length, partsRequired.length);

      for (var i = 0; i < maxLen; i++) {
        final c = i < partsCurrent.length ? partsCurrent[i] : 0;
        final r = i < partsRequired.length ? partsRequired[i] : 0;
        if (c < r) return true;
        if (c > r) return false;
      }
    } catch (_) {}
    return false;
  }
}
