import 'dart:math' as math;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
