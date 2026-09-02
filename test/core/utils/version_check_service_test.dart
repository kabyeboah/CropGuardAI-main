import 'package:cropguard_flutter/core/config/app_secrets.dart';
import 'package:cropguard_flutter/core/utils/version_check_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionCheckService Store URL Resolution', () {
    setUp(() {
      AppSecrets.reset();
    });

    tearDown(() {
      AppSecrets.reset();
    });

    test('getStoreUri returns Android Play Store URL by default on Android',
        () {
      final uri = VersionCheckService.getStoreUri(TargetPlatform.android);
      expect(
        uri.toString(),
        'https://play.google.com/store/apps/details?id=com.cropguard.ai.app',
      );
    });

    test('getStoreUri returns Apple App Store URL on iOS', () {
      final uri = VersionCheckService.getStoreUri(TargetPlatform.iOS);
      expect(
        uri.toString(),
        'https://apps.apple.com/app/com.cropguard.ai.app',
      );
    });

    test('getStoreUri uses overridden package names from AppSecrets', () {
      AppSecrets.dartDefineAndroidPackageOverride = 'org.custom.cropguard';
      AppSecrets.dartDefineIosBundleIdOverride = 'org.custom.cropguard.ios';

      final androidUri =
          VersionCheckService.getStoreUri(TargetPlatform.android);
      expect(
        androidUri.toString(),
        'https://play.google.com/store/apps/details?id=org.custom.cropguard',
      );

      final iosUri = VersionCheckService.getStoreUri(TargetPlatform.iOS);
      expect(
        iosUri.toString(),
        'https://apps.apple.com/app/org.custom.cropguard.ios',
      );
    });
  });
}
