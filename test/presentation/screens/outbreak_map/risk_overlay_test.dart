import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/theme/app_theme.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/outbreak_map/outbreak_map_screen.dart';

class MockCommunityRepository extends Mock implements ICommunityRepository {}
class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

void main() {
  final sl = GetIt.instance;
  late MockCommunityRepository mockCommunityRepo;
  late MockFirebaseAuthService mockAuthService;

  setUp(() {
    sl.reset();

    mockCommunityRepo = MockCommunityRepository();
    mockAuthService = MockFirebaseAuthService();

    sl.registerSingleton<ICommunityRepository>(mockCommunityRepo);
    sl.registerSingleton<FirebaseAuthService>(mockAuthService);

    when(() => mockAuthService.currentUserId).thenReturn('test-user-id');
    when(() => mockAuthService.currentUserIdOrNull).thenReturn('test-user-id');
    when(() => mockAuthService.isSignedIn).thenReturn(true);

    when(() => mockCommunityRepo.getOutbreakReports()).thenAnswer(
      (_) async => Result.success([
        {
          'id': 'r1',
          'isSeed': false,
          'source': 'community',
          'disease': 'Cocoa Black Pod Rot',
          'cropType': 'Cocoa',
          'region': 'Ashanti',
          'severity': 'high',
          'cases': 10,
          'latitude': 6.6666,
          'longitude': -1.6163,
          'reportedAt': DateTime.now().toIso8601String(),
          'verifiedBy': ['u1'],
          'refutedBy': [],
        }
      ]),
    );
  });

  tearDown(() {
    sl.reset();
  });

  Widget wrapWithRouter(Widget child) {
    final router = GoRouter(
      initialLocation: '/outbreak_map',
      routes: [
        GoRoute(
          path: '/outbreak_map',
          builder: (context, state) => child,
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
    );
  }

  testWidgets('OutbreakMapScreen initializes with initialCrop and initialRegion', (tester) async {
    await tester.pumpWidget(wrapWithRouter(
      const OutbreakMapScreen(
        initialCrop: 'Cocoa',
        initialRegion: 'Ashanti',
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(OutbreakMapScreen), findsOneWidget);
  });
}
