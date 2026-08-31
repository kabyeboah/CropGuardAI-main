import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cropguard_flutter/core/di/service_locator.dart';
import 'package:cropguard_flutter/core/theme/app_theme.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/data/remote/firestore_service.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/submissions/my_submissions_screen.dart';

class MockFirestoreService extends Mock implements FirestoreService {}

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockDatabase extends Mock implements Database {}

Widget _wrapScreen() {
  final router = GoRouter(
    initialLocation: '/my_submissions',
    routes: [
      GoRoute(
        path: '/my_submissions',
        builder: (context, state) => const MySubmissionsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Text('Profile Screen')),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirestoreService mockFirestore;
  late MockFirebaseAuthService mockAuth;
  late MockDatabaseHelper mockDb;
  late MockDatabase mockDatabase;

  setUp(() {
    sl.reset();
    mockFirestore = MockFirestoreService();
    mockAuth = MockFirebaseAuthService();
    mockDb = MockDatabaseHelper();
    mockDatabase = MockDatabase();

    sl.registerSingleton<FirestoreService>(mockFirestore);
    sl.registerSingleton<FirebaseAuthService>(mockAuth);
    sl.registerSingleton<DatabaseHelper>(mockDb);

    when(() => mockDatabase.query(any(), orderBy: any(named: 'orderBy')))
        .thenAnswer((_) async => []);
    when(() => mockDb.database).thenAnswer((_) async => mockDatabase);
    when(() => mockAuth.currentUserId).thenReturn('test-user-123');
  });

  tearDown(() {
    sl.reset();
  });

  testWidgets('displays submissions list on successful fetch', (tester) async {
    when(() => mockFirestore.getUserExpertRequests('test-user-123')).thenAnswer(
      (_) async => [
        {
          'type': 'expert_request',
          'diseaseName': 'Tomato Early Blight',
          'message': 'Leaves turning yellow with brown spots',
          'status': 'completed',
          'timestamp': DateTime(2026, 8, 20),
        },
      ],
    );
    when(() => mockFirestore.getUserMissingCrops('test-user-123')).thenAnswer(
      (_) async => [],
    );

    await tester.pumpWidget(_wrapScreen());
    await tester.pumpAndSettle();

    expect(find.text('My Submissions'), findsOneWidget);
    expect(
        find.text('Expert Consultation: Tomato Early Blight'), findsOneWidget);
    expect(find.text('Received & Resolved'), findsOneWidget);
    expect(find.text('Failed to Load Submissions'), findsNothing);
  });

  testWidgets('displays empty state when user has no submissions',
      (tester) async {
    when(() => mockFirestore.getUserExpertRequests('test-user-123')).thenAnswer(
      (_) async => [],
    );
    when(() => mockFirestore.getUserMissingCrops('test-user-123')).thenAnswer(
      (_) async => [],
    );

    await tester.pumpWidget(_wrapScreen());
    await tester.pumpAndSettle();

    expect(find.text('No Submissions Yet'), findsOneWidget);
    expect(find.text('Failed to Load Submissions'), findsNothing);
  });

  testWidgets('renders error banner with retry action on network failure',
      (tester) async {
    var callCount = 0;
    when(() => mockFirestore.getUserExpertRequests('test-user-123'))
        .thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw Exception('Network unreachable');
      }
      return [
        {
          'type': 'expert_request',
          'diseaseName': 'Cassava Mosaic',
          'message': 'Chlorotic mosaic on young leaves',
          'status': 'review_pending',
          'timestamp': DateTime(2026, 8, 28),
        },
      ];
    });
    when(() => mockFirestore.getUserMissingCrops('test-user-123')).thenAnswer(
      (_) async => [],
    );

    await tester.pumpWidget(_wrapScreen());
    await tester.pumpAndSettle();

    // Verify error UI is displayed instead of "No Submissions Yet"
    expect(find.text('Failed to Load Submissions'), findsOneWidget);
    expect(find.text('No Submissions Yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    // Tap retry
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Verify retry succeeds and renders the fetched item
    expect(find.text('Expert Consultation: Cassava Mosaic'), findsOneWidget);
    expect(find.text('Failed to Load Submissions'), findsNothing);
  });
}
