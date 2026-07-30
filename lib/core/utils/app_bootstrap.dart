import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

import '../config/app_secrets.dart';

class AppBootstrap {
  static Future<void> runStartupTasks() async {
    try {
      await _initRemoteConfig();
    } catch (e) {
      dev.log("Remote Config fetch failed: $e");
    }

    try {
      await _initAppCheck();
    } catch (e) {
      dev.log("App Check install failed: $e");
    }
  }

  static Future<void> _initRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.fetchAndActivate();

    final ghanaNlpKey = remoteConfig.getString('ghana_nlp_subscription_key');
    if (ghanaNlpKey.isNotEmpty) {
      AppSecrets.setGhanaNlpSubscriptionKey(ghanaNlpKey);
    }

    // Cloudinary config also resolves via Remote Config so it need not ship in
    // a bundled .env (community image uploads).
    AppSecrets.setCloudinaryConfig(
      cloudName: remoteConfig.getString('cloudinary_cloud_name'),
      uploadPreset: remoteConfig.getString('cloudinary_upload_preset'),
    );

    // Password-reset deep-link domain can be patched via Remote Config without
    // a store release. Falls back to the bundled default when not set.
    final resetUrl = remoteConfig.getString('password_reset_continue_url');
    final androidPkg = remoteConfig.getString('android_package_name');
    final iosBundleId = remoteConfig.getString('ios_bundle_id');
    if (resetUrl.isNotEmpty || androidPkg.isNotEmpty || iosBundleId.isNotEmpty) {
      AppSecrets.setPasswordResetConfig(
        continueUrl: resetUrl.isNotEmpty ? resetUrl : null,
        androidPackage: androidPkg.isNotEmpty ? androidPkg : null,
        iosBundleId: iosBundleId.isNotEmpty ? iosBundleId : null,
      );
    }
  }

  static Future<void> _initAppCheck() async {
    // Release builds (Play Store installs) attest with Play Integrity. Debug /
    // profile / sideloaded builds use the debug provider so App Check does not
    // inject an invalid token into every Firebase request during development.
    //
    // For Play Integrity to succeed, the app's SHA-256 signing certificate must
    // be registered in the Firebase Console (App Check → apps) and App Check
    // enforcement enabled per-service. See docs/APP_CHECK.md.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: const AppleDeviceCheckProvider(),
    );
  }
}
