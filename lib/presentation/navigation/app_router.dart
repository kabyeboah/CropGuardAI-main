import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/firebase_auth_service.dart';
import '../../data/remote/firestore_service.dart';
import '../../data/remote/image_upload_service.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_community_repository.dart';
import '../../domain/repositories/i_detection_repository.dart';
import '../../domain/usecases/auth/send_password_reset_usecase.dart';
import '../../domain/usecases/weather/get_weather_usecase.dart';
import '../../core/utils/connectivity_service.dart';
import '../../core/utils/analytics_service.dart';
import '../../core/utils/app_lock_controller.dart';
import '../screens/lock/biometric_lock_screen.dart';
import '../screens/community/community_provider.dart';
import '../screens/result/result_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/home_provider.dart';
import '../screens/scanner/scanner_screen.dart';
import '../screens/result/result_screen.dart';
import '../screens/result/low_confidence_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/library/disease_library_screen.dart';
import '../screens/outbreak_map/outbreak_map_screen.dart';
import '../screens/treatment_tracker/treatment_tracker_screen.dart';
import '../screens/treatment_tracker/treatment_tracker_provider.dart';
import '../screens/legal/privacy_policy_screen.dart';
// TermsOfServiceScreen is defined in privacy_policy_screen.dart
import '../screens/analysing/analysing_screen.dart';
import '../screens/result/batch_result_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/more/chemical_dosage_calculator_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/submissions/my_submissions_screen.dart';
import '../screens/forgot_password/forgot_password_provider.dart';
import '../screens/forgot_password/forgot_password_screen.dart';
import '../screens/reset_password/reset_password_screen.dart';
import '../screens/error/unknown_route_screen.dart';
import '../../core/utils/auth_state_notifier.dart';
import '../../domain/models/low_confidence_extra.dart';

/// Equivalent of CropGuardNavGraph.kt
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    observers: [sl<AnalyticsService>().observer],
    // Re-run redirect when the biometric lock or auth state flips.
    refreshListenable: Listenable.merge([
      sl<AppLockController>(),
      sl<AuthStateNotifier>(),
    ]),
    errorBuilder: (context, state) => const UnknownRouteScreen(),
    redirect: (context, state) {
      final path = state.matchedLocation;
      final publicRoutes = [
        '/splash',
        '/onboarding',
        '/login',
        '/register',
        '/forgot_password',
        '/reset_password',
        '/privacy_policy',
        '/terms_of_service',
        '/lock',
      ];
      final isPublic = publicRoutes.contains(path);
      final isSignedIn = sl<FirebaseAuthService>().isSignedIn;

      // Biometric app-lock: gate every signed-in route until unlocked.
      if (sl<AppLockController>().isLocked && isSignedIn && path != '/lock') {
        return '/lock';
      }

      if (!isSignedIn && !isPublic) {
        return '/login';
      }
      return null;
    },
    routes: [
      // ─── Auth flow ─────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/lock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const BiometricLockScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot_password',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) {
          final email = (state.extra as String?) ?? '';
          return ChangeNotifierProvider(
            create: (_) => ForgotPasswordProvider(
              sl<SendPasswordResetUseCase>(),
            ),
            child: ForgotPasswordScreen(initialEmail: email),
          );
        },
      ),
      GoRoute(
        path: '/reset_password',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) {
          // oobCode arrives as a query param on the deep link / continue URL.
          final code = state.uri.queryParameters['oobCode'] ?? '';
          return ResetPasswordScreen(oobCode: code);
        },
      ),

      // ─── Main shell with bottom nav ────────────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (ctx, state, child) =>
            _BottomNavShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (ctx, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (ctx, state) => const MoreScreen(),
          ),
        ],
      ),

      // ─── Full-screen routes ────────────────────────────────────────────
      GoRoute(
        path: '/scanner',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/analysing',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) {
          final imagePath =
              state.uri.queryParameters['imagePath'] ?? '';
          return AnalisingScreen(imagePath: imagePath);
        },
      ),
      GoRoute(
        path: '/result/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => ResultProvider(
                  sl<IDetectionRepository>(),
                  sl<ICommunityRepository>(),
                  sl<GetWeatherUseCase>(),
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => TreatmentTrackerProvider(
                  sl<DatabaseHelper>(),
                  sl<IAuthRepository>(),
                  sl<FirestoreService>(),
                ),
              ),
            ],
            child: ResultScreen(detectionId: id),
          );
        },
      ),
      GoRoute(
        path: '/batch_result',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const BatchResultScreen(),
      ),
      GoRoute(
        path: '/low_confidence',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) {
          // Prefer the typed extra object; fall back to query params for
          // backward-compat with any deep-links or tests that use them.
          if (state.extra is LowConfidenceExtra) {
            final extra = state.extra as LowConfidenceExtra;
            return LowConfidenceScreen(
              confidence: extra.confidence,
              imagePath: extra.imagePath,
              topCandidates: extra.topCandidates,
              regionalRisks: extra.regionalRisks,
            );
          }
          final confidence = double.tryParse(
                  state.uri.queryParameters['confidence'] ?? '0') ??
              0.0;
          final imagePath =
              state.uri.queryParameters['imagePath'] ?? '';
          return LowConfidenceScreen(
              confidence: confidence, imagePath: imagePath);
        },
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/submissions',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const MySubmissionsScreen(),
      ),
      GoRoute(
        path: '/community',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => ChangeNotifierProvider(
          create: (_) => CommunityProvider(
            sl<ICommunityRepository>(),
            sl<FirebaseAuthService>(),
            sl<ImageUploadService>(),
            sl<ConnectivityService>(),
          ),
          child: const CommunityScreen(),
        ),
      ),
      GoRoute(
        path: '/disease_library',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const DiseaseLibraryScreen(),
      ),
      GoRoute(
        path: '/dosage_calculator',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const ChemicalDosageCalculatorScreen(),
      ),
      GoRoute(
        path: '/outbreak_map',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => OutbreakMapScreen(
          prefill: state.extra is OutbreakReportPrefill
              ? state.extra as OutbreakReportPrefill
              : null,
          initialCrop: state.uri.queryParameters['crop'],
          initialRegion: state.uri.queryParameters['region'],
        ),
      ),
      GoRoute(
        path: '/treatment_tracker',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => ChangeNotifierProvider(
          create: (_) => TreatmentTrackerProvider(
            sl<DatabaseHelper>(),
            sl<IAuthRepository>(),
            sl<FirestoreService>(),
            seed: state.extra is TreatmentSeed
                ? state.extra as TreatmentSeed
                : null,
          ),
          child: const TreatmentTrackerScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy_policy',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/terms_of_service',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (ctx, state) => const NotificationsScreen(),
      ),
    ],
  );
}

class _BottomNavShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _BottomNavShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _CropNavBar(location: location),
    );
  }
}

class _CropNavBar extends StatelessWidget {
  final String location;

  const _CropNavBar({required this.location});

  int _selectedIndex() {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/more')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final selected = _selectedIndex();

    return Semantics(
      container: true,
      label: context.l10n.mainNavigation,
      child: BottomAppBar(
        color: colors.surface,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: l10n.home,
                selected: selected == 0,
                onTap: () {
                  // Refresh so changes from other tabs (e.g. a deleted scan)
                  // are reflected when returning to Home.
                  context.read<HomeProvider>().refreshData();
                  context.go('/home');
                },
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.history_outlined,
                selectedIcon: Icons.history,
                label: l10n.history,
                selected: selected == 1,
                onTap: () => context.go('/history'),
              ),
            ),
            Expanded(
              child: _ScanNavItem(
                onTap: () => context.push('/scanner'),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.more_horiz_outlined,
                selectedIcon: Icons.more_horiz,
                label: l10n.more,
                selected: selected == 3,
                onTap: () => context.go('/more'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: context.l10n.scan,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.scan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.primary : colors.onBackgroundSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
