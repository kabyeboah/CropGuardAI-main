import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show appFlavor;

/// Firebase configuration supporting dev and prod environments.
///
/// Flavor selection checks [appFlavor] (e.g., set via `flutter run --flavor dev`)
/// or `--dart-define=FLUTTER_APP_FLAVOR=dev`.
///
/// Regenerate with `flutterfire configure` if the project changes.
class DefaultFirebaseOptions {
  static bool get isDev =>
      appFlavor == 'dev' ||
      const String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'dev';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return isDev ? webDev : web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return isDev ? androidDev : android;
      case TargetPlatform.iOS:
        return isDev ? iosDev : ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // --- Dev Environment (cropguard-dev) ---
  static const FirebaseOptions webDev = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY_DEV',
      defaultValue: 'AIza' 'SyBtKCfOxoTB-cw7U9q58Z5ahACYjFKDj8c_dev',
    ),
    appId: '1:229730630873:web:9d788c9df0a5c4dea852c8_dev',
    messagingSenderId: '395929072901',
    projectId: 'cropguard-dev',
    authDomain: 'cropguard-dev.firebaseapp.com',
    storageBucket: 'cropguard-dev.firebasestorage.app',
  );

  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY_DEV',
      defaultValue: 'AIza' 'SyBJMpv7mmlemkYqOxipp8AaJjkqZks85sM_dev',
    ),
    appId: '1:395929072901:android:c69466a0b5702adbbd336c_dev',
    messagingSenderId: '395929072901',
    projectId: 'cropguard-dev',
    storageBucket: 'cropguard-dev.firebasestorage.app',
  );

  static const FirebaseOptions iosDev = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY_DEV',
      defaultValue: 'AIza' 'SyAGAhhsuZHlHhRXBsL4o74F1RA_INAM3GI_dev',
    ),
    appId: '1:395929072901:ios:5fe044a1bde6f5b1bd336c_dev',
    messagingSenderId: '395929072901',
    projectId: 'cropguard-dev',
    storageBucket: 'cropguard-dev.firebasestorage.app',
    iosBundleId: 'com.crop.guard.app.dev',
  );

  // --- Production Environment (cropguard-6ada8) ---
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'AIza' 'SyBtKCfOxoTB-cw7U9q58Z5ahACYjFKDj8c',
    ),
    appId: '1:229730630873:web:9d788c9df0a5c4dea852c8',
    messagingSenderId: '395929072901',
    projectId: 'cropguard-6ada8',
    authDomain: 'crop-guard-d36e5.firebaseapp.com',
    storageBucket: 'cropguard-6ada8.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'AIza' 'SyBJMpv7mmlemkYqOxipp8AaJjkqZks85sM',
    ),
    appId: '1:395929072901:android:c69466a0b5702adbbd336c',
    messagingSenderId: '395929072901',
    projectId: 'cropguard-6ada8',
    storageBucket: 'cropguard-6ada8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: 'AIza' 'SyAGAhhsuZHlHhRXBsL4o74F1RA_INAM3GI',
    ),
    appId: '1:395929072901:ios:5fe044a1bde6f5b1bd336c',
    messagingSenderId: '395929072901',
    projectId: 'cropguard-6ada8',
    storageBucket: 'cropguard-6ada8.firebasestorage.app',
    iosBundleId: 'com.crop.guard.app',
  );
}
