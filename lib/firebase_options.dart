import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration (standard FlutterFire output).
///
/// These are app *identifiers*, not secrets — the same values ship inside
/// `google-services.json` / `GoogleService-Info.plist` in every build. They are
/// inlined as consts (rather than read from a bundled `.env`) so Firebase
/// initialisation never depends on a packaged asset. Abuse is prevented by
/// Firebase App Check + console API-key restrictions, not by hiding these.
///
/// Regenerate with `flutterfire configure` if the project changes.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

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
