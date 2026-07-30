import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/utils/notification_helper.dart';
import 'core/utils/background_tasks.dart';
import 'core/utils/app_bootstrap.dart';
import 'core/utils/analytics_service.dart';
import 'core/utils/app_lock_controller.dart';
import 'core/utils/deep_link_service.dart';
import 'presentation/navigation/app_router.dart';
import 'firebase_options.dart';

import 'dart:async';
import 'core/utils/app_logger.dart';

// Start the stopwatch immediately when the app entrypoint file is loaded
final Stopwatch startupStopwatch = Stopwatch()..start();

void main() async {
  // firebaseReady is set to true once Firebase.initializeApp() completes so
  // the zone error handler can safely decide whether Crashlytics is available.
  bool firebaseReady = false;

  unawaited(runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Optional local-dev convenience only. `.env` is NOT bundled as an asset
    // (secrets must never ship in the binary), so this load is expected to be a
    // no-op in release — production secrets come from --dart-define / Firebase
    // Remote Config (see core/config/app_secrets.dart). To use a .env locally,
    // a developer can temporarily add it back to pubspec assets.
    if (kDebugMode) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // No .env present — fine; AppSecrets falls back to dart-define/Remote Config.
      }
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;

    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      AppLogger.e('Flutter Error', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    try {
      await setupServiceLocator();
    } catch (e, s) {
      AppLogger.e('Service locator registration failed', e, s);
    }

    // Initialize helpers asynchronously so slow/flaky native channel initializations
    // cannot block the initial frame (runApp) and leave the screen blank.
    unawaited(() async {
      try {
        await NotificationHelper.init();
      } catch (e, s) {
        AppLogger.e('NotificationHelper initialization failed', e, s);
      }
      try {
        await BackgroundTaskHelper.init();
      } catch (e, s) {
        AppLogger.e('BackgroundTaskHelper initialization failed', e, s);
      }
    }());

    // Start observing app lifecycle for the biometric app-lock (no-op until the
    // user enables it in Settings).
    try {
      sl<AppLockController>().start();
    } catch (e, s) {
      AppLogger.e('AppLockController startup failed', e, s);
    }

    // Attribute crashes and analytics to the current user across every auth
    // path (login/register/google/anonymous/logout). uid is cleared on sign-out.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(FirebaseCrashlytics.instance.setUserIdentifier(user?.uid ?? ''));
      unawaited(sl<AnalyticsService>().setUser(isAnonymous: user?.isAnonymous ?? false));
    });

    runApp(
      MultiProvider(
        providers: buildProviders(),
        child: const CropGuardApp(),
      ),
    );

    // Non-critical startup work runs *after* the first frame so a slow or
    // flaky network (Remote Config fetch can take up to its 1-min timeout)
    // never blocks the splash screen. Nothing in the first seconds of app
    // life depends on these; secrets fall back to .env until they resolve.
    unawaited(AppBootstrap.runStartupTasks());
    // Register the periodic outbreak-proximity check (no-op on non-Android and
    // a no-op re-register thanks to the `keep` policy).
    unawaited(BackgroundTaskHelper.scheduleOutbreakAlerts());
    // Listen for password-reset (and future) deep links so the email link
    // opens the in-app reset screen rather than a web page.
    unawaited(sl<DeepLinkService>().init(AppRouter.router));
  }, (error, stack) {
    // Guard against calling Crashlytics before Firebase.initializeApp() has
    // completed — that call would itself throw, producing an unhandled
    // secondary exception that crashes the process before any error is logged.
    if (firebaseReady) {
      try {
        unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
      } catch (_) {}
    }
    AppLogger.e('Uncaught Error', error, stack);
  }));
}
