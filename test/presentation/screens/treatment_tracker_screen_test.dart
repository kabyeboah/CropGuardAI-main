import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:cropguard_flutter/core/theme/app_theme.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/firestore_service.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/treatment_tracker/treatment_tracker_provider.dart';
import 'package:cropguard_flutter/presentation/screens/treatment_tracker/treatment_tracker_screen.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockFirestoreService extends Mock implements FirestoreService {}

Widget _wrapScreen({
  required TreatmentTrackerProvider provider,
}) {
  final router = GoRouter(
    initialLocation: '/treatment_tracker',
    routes: [
      GoRoute(
        path: '/treatment_tracker',
        builder: (context, state) => const TreatmentTrackerScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Screen')),
      ),
    ],
  );

  return ChangeNotifierProvider<TreatmentTrackerProvider>.value(
    value: provider,
    child: MaterialApp.router(
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
    ),
  );
}

void main() {
  late MockDatabaseHelper mockDb;
  late MockIAuthRepository mockAuthRepo;
  late MockFirestoreService mockFirestore;

  setUp(() {
    mockDb = MockDatabaseHelper();
    mockAuthRepo = MockIAuthRepository();
    mockFirestore = MockFirestoreService();

    when(() => mockAuthRepo.currentUser).thenReturn(null);
  });

  testWidgets('Renders empty state when no treatment plans exist',
      (tester) async {
    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => []);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);
    when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);

    final provider =
        TreatmentTrackerProvider(mockDb, mockAuthRepo, mockFirestore);
    await tester.pumpWidget(_wrapScreen(provider: provider));
    await tester.pumpAndSettle();

    expect(find.byType(TreatmentTrackerScreen), findsOneWidget);
    expect(find.text('No treatment plans yet'), findsOneWidget);
  });

  testWidgets(
      'Renders active treatment plan group with steps and allows filtering',
      (tester) async {
    final now = DateTime.now();
    final step1 = TreatmentPlan(
      id: 'step_1',
      userId: 'guest',
      detectionId: 101,
      cropType: 'Cassava',
      diseaseName: 'Cassava Mosaic Disease',
      step: 'Prune affected leaves',
      completed: false,
      dueDate: now.add(const Duration(days: 1)),
      createdAt: now,
    );

    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => [step1]);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 1);
    when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);

    final provider =
        TreatmentTrackerProvider(mockDb, mockAuthRepo, mockFirestore);
    await tester.pumpWidget(_wrapScreen(provider: provider));
    await tester.pumpAndSettle();

    // Verify card rendered
    expect(find.text('Cassava — Cassava Mosaic Disease'), findsOneWidget);
    expect(find.text('Prune affected leaves'), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);

    // Tap Active filter chip
    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Cassava — Cassava Mosaic Disease'), findsOneWidget);

    // Tap Completed filter chip
    await tester.tap(find.text('Completed (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No Completed Plans Yet'), findsOneWidget);
  });

  testWidgets('Toggling step checkbox updates treatment status',
      (tester) async {
    final now = DateTime.now();
    final step1 = TreatmentPlan(
      id: 'step_1',
      userId: 'guest',
      detectionId: 101,
      cropType: 'Maize',
      diseaseName: 'Common Rust',
      step: 'Apply fungicide',
      completed: false,
      dueDate: now,
      createdAt: now,
    );

    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => [step1]);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 1);
    when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);
    when(() => mockDb.updateTreatmentCompleted('step_1', true))
        .thenAnswer((_) async => 1);

    final provider =
        TreatmentTrackerProvider(mockDb, mockAuthRepo, mockFirestore);
    await tester.pumpWidget(_wrapScreen(provider: provider));
    await tester.pumpAndSettle();

    await provider.toggleStepById('step_1');
    await tester.pumpAndSettle();

    verify(() => mockDb.updateTreatmentCompleted('step_1', true)).called(1);
  });

  testWidgets(
      'Delete icon shows confirmation dialog and deletes plan on confirm',
      (tester) async {
    final now = DateTime.now();
    final step1 = TreatmentPlan(
      id: 'step_del',
      userId: 'guest',
      detectionId: 202,
      cropType: 'Tomato',
      diseaseName: 'Late Blight',
      step: 'Remove blighted vines',
      completed: false,
      dueDate: now,
      createdAt: now,
    );

    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => [step1]);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 1);
    when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);
    when(() => mockDb.deleteTreatment('step_del')).thenAnswer((_) async => 1);

    final provider =
        TreatmentTrackerProvider(mockDb, mockAuthRepo, mockFirestore);
    await tester.pumpWidget(_wrapScreen(provider: provider));
    await tester.pumpAndSettle();

    // Tap delete icon
    final deleteIcon = find.byTooltip('Delete Plan');
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    // Verify dialog pops up
    expect(find.text('Delete Treatment Plan?'), findsOneWidget);

    // Prepare mock return for refresh after deletion
    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => []);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);

    // Tap Delete button in dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockDb.deleteTreatment('step_del')).called(1);
    expect(find.text('No treatment plans yet'), findsOneWidget);
  });

  testWidgets(
      'Swiping a step shows confirmation dialog, cancelling retains step',
      (tester) async {
    final now = DateTime.now();
    final step1 = TreatmentPlan(
      id: 'step_swipe_1',
      userId: 'guest',
      detectionId: 303,
      cropType: 'Tomato',
      diseaseName: 'Early Blight',
      step: 'Mulch around the base',
      completed: false,
      dueDate: now,
      createdAt: now,
    );

    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => [step1]);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 1);
    when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);

    final provider =
        TreatmentTrackerProvider(mockDb, mockAuthRepo, mockFirestore);
    await tester.pumpWidget(_wrapScreen(provider: provider));
    await tester.pumpAndSettle();

    expect(find.text('Mulch around the base'), findsOneWidget);

    // Swipe the step
    await tester.drag(
        find.text('Mulch around the base'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.text('Delete Treatment Step?'), findsOneWidget);
    expect(
        find.text(
            'This will permanently delete the step "Mulch around the base".'),
        findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify step is not deleted and still visible
    verifyNever(() => mockDb.deleteTreatment(any()));
    expect(find.text('Mulch around the base'), findsOneWidget);
  });

  testWidgets('Swiping a step and confirming deletes the step', (tester) async {
    final now = DateTime.now();
    final step1 = TreatmentPlan(
      id: 'step_swipe_2',
      userId: 'guest',
      detectionId: 303,
      cropType: 'Tomato',
      diseaseName: 'Early Blight',
      step: 'Mulch around the base',
      completed: false,
      dueDate: now,
      createdAt: now,
    );

    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => [step1]);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 1);
    when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);
    when(() => mockDb.deleteTreatment('step_swipe_2'))
        .thenAnswer((_) async => 1);

    final provider =
        TreatmentTrackerProvider(mockDb, mockAuthRepo, mockFirestore);
    await tester.pumpWidget(_wrapScreen(provider: provider));
    await tester.pumpAndSettle();

    // Swipe the step
    await tester.drag(
        find.text('Mulch around the base'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.text('Delete Treatment Step?'), findsOneWidget);

    // Prepare mock return for refresh after deletion
    when(() => mockDb.getAllTreatments(
          userId: 'guest',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => []);
    when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
        .thenAnswer((_) async => 0);

    // Tap Delete button in dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockDb.deleteTreatment('step_swipe_2')).called(1);
  });
}
