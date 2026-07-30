import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localizations.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/connectivity_service.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/screens/settings/settings_provider.dart';

class CropGuardApp extends StatefulWidget {
  const CropGuardApp({super.key});

  @override
  State<CropGuardApp> createState() => _CropGuardAppState();
}

class _CropGuardAppState extends State<CropGuardApp> {
  @override
  void dispose() {
    // Properly dispose the ConnectivityService singleton so it de-registers
    // its WidgetsBindingObserver and cancels its timers/stream subscriptions.
    sl<ConnectivityService>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp.router(
          title: 'CropGuard AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          routerConfig: AppRouter.router,
          locale: settings.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FallbackMaterialLocalizationsDelegate(),
            FallbackCupertinoLocalizationsDelegate(),
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final scale = settings.largeTextMode ? 1.3 : 1.0;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
