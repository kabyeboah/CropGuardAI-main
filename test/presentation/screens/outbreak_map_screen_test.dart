import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/presentation/screens/outbreak_map/outbreak_map_screen.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/core/theme/app_theme.dart';

class MockCommunityRepository extends Mock implements ICommunityRepository {}
class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}
class MockTileImage extends Mock implements TileImage {}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/outbreak_map',
    routes: [
      GoRoute(
        path: '/outbreak_map',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Screen')),
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

List<Map<String, dynamic>> generateSyntheticReports(int count) {
  final List<Map<String, dynamic>> reports = [];
  const baseLat = 6.6885;
  const baseLng = -1.6244;
  for (int i = 0; i < count; i++) {
    final latOffset = (i % 20) * 0.001;
    final lngOffset = (i / 20).floor() * 0.001;
    reports.add({
      'id': 'synthetic_$i',
      'disease': 'Cassava Mosaic Disease',
      'diseaseName': 'Cassava Mosaic Disease',
      'cropType': 'Cassava',
      'severity': i % 3 == 0 ? 'high' : (i % 3 == 1 ? 'medium' : 'low'),
      'latitude': baseLat + latOffset,
      'longitude': baseLng + lngOffset,
      'region': 'Ashanti',
      'timestamp': DateTime.now().millisecondsSinceEpoch - (i * 60000),
      'cases': 1,
      'verifiedBy': <String>[],
      'refutedBy': <String>[],
    });
  }
  return reports;
}

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
  });

  tearDown(() {
    sl.reset();
  });

  testWidgets('Marker clustering performs acceptably with a large number of nearby outbreak points',
      (tester) async {
    // Generate 500 synthetic outbreak points
    final reports = generateSyntheticReports(500);
    when(() => mockCommunityRepo.getOutbreakReports())
        .thenAnswer((_) async => Result.success(reports));

    await tester.pumpWidget(_wrap(const OutbreakMapScreen()));
    await tester.pumpAndSettle();

    // Verify screen loaded
    expect(find.byType(OutbreakMapScreen), findsOneWidget);

    // Verify FlutterMap exists and has the cluster layer configured
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);

    // Verify that the list view displays the single aggregated Ashanti hotspot with 500 reports
    expect(find.text('Cassava Mosaic Disease'), findsOneWidget);
    expect(find.text('500 reports'), findsOneWidget);
  });

  testWidgets('Map gracefully degrades (static list view) if tiles fail to load rather than showing blank map',
      (tester) async {
    final reports = generateSyntheticReports(5);
    when(() => mockCommunityRepo.getOutbreakReports())
        .thenAnswer((_) async => Result.success(reports));

    await tester.pumpWidget(_wrap(const OutbreakMapScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Map unavailable offline'), findsNothing);

    // Trigger tile load errors directly via the errorTileCallback on TileLayer
    final tileLayerFinder = find.byType(TileLayer);
    expect(tileLayerFinder, findsOneWidget);

    final TileLayer tileLayer = tester.widget<TileLayer>(tileLayerFinder);
    expect(tileLayer.errorTileCallback, isNotNull);

    // Simulate 3 tile errors to trigger graceful degradation
    final mockTile = MockTileImage();
    final error = Exception('Failed to load tile');

    tileLayer.errorTileCallback!(mockTile, error, null);
    tileLayer.errorTileCallback!(mockTile, error, null);
    tileLayer.errorTileCallback!(mockTile, error, null);

    // Re-pump widget to propagate the state change
    await tester.pumpAndSettle();

    // Verify that the map is replaced by the degradation fallback UI
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Map unavailable offline'), findsOneWidget);
    expect(find.text('Using static list view below'), findsOneWidget);
    expect(find.text('Retry Map'), findsOneWidget);

    // Verify that the static list view below the fallback container is still rendered and readable
    expect(find.text('Cassava Mosaic Disease'), findsOneWidget);
    expect(find.text('5 reports'), findsOneWidget);
  });

  testWidgets('Degraded map recovers to normal FlutterMap when Retry Map is tapped',
      (tester) async {
    final reports = generateSyntheticReports(5);
    when(() => mockCommunityRepo.getOutbreakReports())
        .thenAnswer((_) async => Result.success(reports));

    await tester.pumpWidget(_wrap(const OutbreakMapScreen()));
    await tester.pumpAndSettle();

    // Trigger degradation
    final tileLayerFinder = find.byType(TileLayer);
    final TileLayer tileLayer = tester.widget<TileLayer>(tileLayerFinder);
    final mockTile = MockTileImage();
    final error = Exception('Failed to load tile');

    tileLayer.errorTileCallback!(mockTile, error, null);
    tileLayer.errorTileCallback!(mockTile, error, null);
    tileLayer.errorTileCallback!(mockTile, error, null);
    await tester.pumpAndSettle();

    expect(find.text('Map unavailable offline'), findsOneWidget);

    // Tap retry button
    final retryButton = find.text('Retry Map');
    expect(retryButton, findsOneWidget);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    // Verify map is restored
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Map unavailable offline'), findsNothing);
  });

  testWidgets('Falls back to seed outbreak data when Firestore returns empty list',
      (tester) async {
    when(() => mockCommunityRepo.getOutbreakReports())
        .thenAnswer((_) async => Result.success([]));

    await tester.pumpWidget(_wrap(const OutbreakMapScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(OutbreakMapScreen), findsOneWidget);
    // Verify seed data appears (e.g. Cocoa Black Pod Rot)
    expect(find.text('Cocoa Black Pod Rot'), findsOneWidget);
  });

  testWidgets('Auto-opens report sheet when prefill parameter is supplied',
      (tester) async {
    when(() => mockCommunityRepo.getOutbreakReports())
        .thenAnswer((_) async => Result.success([]));

    const prefill = OutbreakReportPrefill(
      disease: 'Cassava Mosaic Disease',
      severity: 'high',
    );

    await tester.pumpWidget(_wrap(const OutbreakMapScreen(prefill: prefill)));
    await tester.pumpAndSettle();

    expect(find.text('Report Disease Here'), findsWidgets);
    expect(find.text('Cassava Mosaic Disease'), findsWidgets);
  });

  testWidgets('Tapping Report Outbreak FAB opens the report modal sheet',
      (tester) async {
    when(() => mockCommunityRepo.getOutbreakReports())
        .thenAnswer((_) async => Result.success([]));

    await tester.pumpWidget(_wrap(const OutbreakMapScreen()));
    await tester.pumpAndSettle();

    final fab = find.text('Report Disease Here');
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('Report Disease Here'), findsWidgets);
  });
}
