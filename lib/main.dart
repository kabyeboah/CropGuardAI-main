import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_secrets.dart';
import 'core/di/service_locator.dart';
import 'core/utils/analytics_service.dart';
import 'core/utils/app_bootstrap.dart';
import 'core/utils/app_lock_controller.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/background_tasks.dart';
import 'core/utils/deep_link_service.dart';
import 'core/utils/notification_helper.dart';
import 'core/utils/push_notification_service.dart';
import 'presentation/navigation/app_router.dart';

// Start the stopwatch immediately when the app entrypoint file is loaded
final Stopwatch startupStopwatch = Stopwatch()..start();

void main() async {
  unawaited(runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Optional local-dev convenience only. `.env` is NOT bundled as an asset
    // (secrets must never ship in the binary), so this load is expected to be a
    // no-op in release — production secrets come from --dart-define / Supabase
    // app_config table.
    if (kDebugMode) {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // No .env present — fine; AppSecrets falls back to dart-define/app_config.
      }
    }

    // Initialize Supabase for Auth, PostgreSQL DB, and Cloud Storage
    try {
      await Supabase.initialize(
        url: AppSecrets.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppSecrets.supabaseAnonKey,
      );
    } catch (e, s) {
      AppLogger.e('Supabase initialization failed', e, s);
    }

    FlutterError.onError = (details) {
      AppLogger.e('Flutter Error', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e('Platform Error', error, stack);
      return true;
    };
    try {
      await setupServiceLocator();
      // Apply persisted consent before any background or auth listener runs
      final prefs = sl<SharedPreferences>();
      final isAnalyticsAllowed = prefs.getBool('analytics_enabled') ?? false;
      await sl<AnalyticsService>().setEnabled(isAnalyticsAllowed);
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
        await PushNotificationService.init(
          onNotificationTap: (route) {
            if (route != null && route.isNotEmpty) {
              AppRouter.router.push(route);
            }
          },
        );
      } catch (e, s) {
        AppLogger.e('PushNotificationService initialization failed', e, s);
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

    // Handle auth state changes and route redirects
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (data.event == AuthChangeEvent.passwordRecovery) {
          AppRouter.router.go('/reset_password');
        }
        final analytics =
            sl.isRegistered<AnalyticsService>() ? sl<AnalyticsService>() : null;
        if (analytics?.isEnabled == true) {
          unawaited(analytics?.setUser(isAnonymous: user?.isAnonymous ?? false));
        }
      });
    } catch (_) {}

    runApp(
      MultiProvider(
        providers: buildProviders(),
        child: const CropGuardApp(),
      ),
    );

    // Non-critical startup work runs *after* the first frame so a slow network
    // never blocks the splash screen.
    unawaited(AppBootstrap.runStartupTasks());
    // Register the periodic outbreak-proximity check (no-op on non-Android and
    // a no-op re-register thanks to the `keep` policy).
    unawaited(BackgroundTaskHelper.scheduleOutbreakAlerts());
    // Listen for password-reset (and future) deep links so the email link
    // opens the in-app reset screen rather than a web page.
    unawaited(sl<DeepLinkService>().init(AppRouter.router));
  }, (error, stack) {
    AppLogger.e('Uncaught Error', error, stack);
  }));
}
