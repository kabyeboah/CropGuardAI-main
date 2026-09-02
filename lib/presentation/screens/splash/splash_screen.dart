import 'dart:async';

import '../../../data/remote/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/root_detection_helper.dart';
import '../../../core/utils/version_check_service.dart';
import '../../../core/utils/analytics_service.dart';
import '../../../domain/repositories/i_classifier_repository.dart';
import '../../../main.dart' show startupStopwatch;

/// Equivalent of SplashScreen.kt — 1.5s delay then route based on onboarding flag
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (startupStopwatch.isRunning) {
        startupStopwatch.stop();
        final elapsedMs = startupStopwatch.elapsedMilliseconds;
        AppLogger.i('App cold start time: ${elapsedMs}ms');
        sl<AnalyticsService>().logColdStart(elapsedMs);
      }
    });

    // Fire-and-forget ML model preload so the first scan does not incur cold-start latency.
    if (sl.isRegistered<IClassifierRepository>()) {
      unawaited(sl<IClassifierRepository>().loadModel());
    }

    _navigate();
  }

  Future<void> _navigate() async {
    // Minimum splash duration (matches SplashViewModel 1500ms delay)
    await Future.delayed(const Duration(milliseconds: 1500));
    final prefs = sl<SharedPreferences>();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    if (!mounted) return;

    final isRooted = await RootDetectionHelper.isRooted();
    if (isRooted) {
      AppLogger.w('Device is rooted/jailbroken. Prompting soft warning.');
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            icon: const Icon(Icons.security_update_warning,
                color: Colors.orange, size: 40),
            title: Text(context.l10n.securityWarningTitle),
            content: Text(context.l10n.securityWarningBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(context.l10n.proceedAnyway),
              ),
            ],
          ),
        );
      }
    }

    if (!mounted) return;

    // ── Force-update gate (0.14) ───────────────────────────────────────────
    // Check Remote Config `min_required_app_version`. On failure, proceed
    // normally — a flaky Remote Config check must never block app access.
    bool updateRequired = false;
    try {
      updateRequired = await VersionCheckService.isUpdateRequired();
    } catch (e) {
      AppLogger.w('SplashScreen: force-update check failed: $e');
    }
    if (!mounted) return;
    if (updateRequired) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.system_update,
                size: 40, color: Color(0xFF16A34A)),
            title: Text(
              context.l10n.updateRequiredTitle,
              textAlign: TextAlign.center,
            ),
            content: Text(
              context.l10n.updateRequiredBody,
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(context.l10n.updateNow),
                onPressed: () async {
                  AppLogger.i('SplashScreen: user tapped Update Now');
                  await VersionCheckService.launchStoreUrl();
                },
              ),
            ],
          ),
        ),
      );
      // After the dialog closes (if it ever does), stop routing — do not let
      // an unsupported version into the app.
      return;
    }

    if (!mounted) return;

    // If the router was already directed elsewhere (e.g. cold-start deep link to /reset_password),
    // do not overwrite the deep link destination.
    final currentLoc = GoRouterState.of(context).matchedLocation;
    if (currentLoc != '/splash') return;

    if (sl<SupabaseAuthService>().currentUser != null) {
      context.go('/home');
    } else if (onboardingDone) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.eco, size: 72, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'CropGuard AI',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.appTagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white.withValues(alpha: 0.7),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
