import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/supabase_auth_service.dart';
import 'package:cropguard_flutter/data/remote/supabase_database_service.dart';
import 'package:cropguard_flutter/data/remote/gemini_cloud_ai_service.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/home/home_provider.dart';
import 'package:cropguard_flutter/presentation/screens/library/disease_library_screen.dart';
import 'package:cropguard_flutter/presentation/screens/more/chemical_dosage_calculator_screen.dart';
import 'package:cropguard_flutter/presentation/screens/result/low_confidence_screen.dart';
import 'package:cropguard_flutter/presentation/screens/result/result_provider.dart';
import 'package:cropguard_flutter/presentation/screens/result/result_screen.dart';
import 'package:cropguard_flutter/presentation/screens/scanner/scanner_provider.dart';
import 'package:cropguard_flutter/presentation/screens/settings/settings_provider.dart';
import 'package:cropguard_flutter/presentation/screens/treatment_tracker/treatment_tracker_provider.dart';
import 'package:cropguard_flutter/presentation/screens/treatment_tracker/treatment_tracker_screen.dart';

class MockSupabaseAuthService extends Mock implements SupabaseAuthService {}

class MockSupabaseDatabaseService extends Mock implements SupabaseDatabaseService {}

class MockGeminiCloudAiService extends Mock implements GeminiCloudAiService {}

class MockCommunityRepository extends Mock implements ICommunityRepository {}

class MockDetectionRepository extends Mock implements IDetectionRepository {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockScannerProvider extends Mock implements ScannerProvider {}

class MockHomeProvider extends Mock implements HomeProvider {}

class MockSettingsProvider extends Mock implements SettingsProvider {}

class MockResultProvider extends Mock implements ResultProvider {}

void main() {
  final sl = GetIt.instance;
  late MockSupabaseAuthService mockAuthService;
  late MockSupabaseDatabaseService mockSupabaseDatabaseService;
  late MockGeminiCloudAiService mockGeminiService;
  late MockCommunityRepository mockCommunityRepo;
  late MockDetectionRepository mockDetectionRepo;
  late MockAuthRepository mockAuthRepo;
  late MockAnalyticsService mockAnalyticsService;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockScannerProvider mockScannerProvider;
  late MockHomeProvider mockHomeProvider;
  late MockSettingsProvider mockSettingsProvider;

  setUp(() {
    sl.reset();
    mockAuthService = MockSupabaseAuthService();
    mockSupabaseDatabaseService = MockSupabaseDatabaseService();
    mockGeminiService = MockGeminiCloudAiService();
    mockCommunityRepo = MockCommunityRepository();
    mockDetectionRepo = MockDetectionRepository();
    mockAuthRepo = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();
    mockDatabaseHelper = MockDatabaseHelper();
    mockScannerProvider = MockScannerProvider();
    mockHomeProvider = MockHomeProvider();
    mockSettingsProvider = MockSettingsProvider();

    sl.registerSingleton<SupabaseAuthService>(mockAuthService);
    sl.registerSingleton<SupabaseDatabaseService>(mockSupabaseDatabaseService);
    sl.registerSingleton<GeminiCloudAiService>(mockGeminiService);
    sl.registerSingleton<ICommunityRepository>(mockCommunityRepo);
    sl.registerSingleton<IDetectionRepository>(mockDetectionRepo);
    sl.registerSingleton<IAuthRepository>(mockAuthRepo);
    sl.registerSingleton<AnalyticsService>(mockAnalyticsService);
    sl.registerSingleton<DatabaseHelper>(mockDatabaseHelper);

    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockAuthService.currentUserId).thenReturn('test_user');
    when(() => mockSettingsProvider.showConfidence).thenReturn(true);
    when(() => mockSettingsProvider.themeMode).thenReturn(ThemeMode.system);
  });

  tearDown(() {
    sl.reset();
  });

  Widget buildTestApp({
    required Widget child,
    ResultProvider? resultProvider,
    TreatmentTrackerProvider? trackerProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScannerProvider>.value(
            value: mockScannerProvider),
        ChangeNotifierProvider<HomeProvider>.value(value: mockHomeProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
            value: mockSettingsProvider),
        if (resultProvider != null)
          ChangeNotifierProvider<ResultProvider>.value(value: resultProvider),
        if (trackerProvider != null)
          ChangeNotifierProvider<TreatmentTrackerProvider>.value(
              value: trackerProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('Disclaimer & Treatment Advisory Coverage Tests', () {
    testWidgets(
        '1. ResultScreen displays both persistent scope disclaimer and treatment advisory',
        (tester) async {
      final detection = DetectionResult(
        id: 1,
        imagePath: '',
        cropType: 'Tomato',
        diseaseLabel: 'Tomato___Late_blight',
        displayName: 'Tomato Late Blight',
        confidence: 0.92,
        isHealthy: false,
        severity: 'severe',
        cause: 'Phytophthora infestans fungus',
        treatments: ['Apply copper fungicide spray', 'Remove infected leaves'],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final mockResultProvider = MockResultProvider();
      when(() => mockResultProvider.isLoading).thenReturn(false);
      when(() => mockResultProvider.result).thenReturn(detection);
      when(() => mockResultProvider.sprayAdvisory).thenReturn('');
      when(() => mockResultProvider.sprayAdvisoryUnavailable).thenReturn(false);
      when(() => mockResultProvider.isWeatherLoading).thenReturn(false);
      when(() => mockResultProvider.feedbackSent).thenReturn(false);
      when(() => mockResultProvider.cropNotFoundSent).thenReturn(false);
      when(() => mockResultProvider.expertRequestSent).thenReturn(false);
      when(() => mockResultProvider.isRequestingExpert).thenReturn(false);
      when(() => mockResultProvider.errorCode).thenReturn(null);
      when(() => mockResultProvider.load(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildTestApp(
          resultProvider: mockResultProvider,
          child: const ResultScreen(detectionId: 1),
        ),
      );
      await tester.pumpAndSettle();

      // Verify scope disclaimer is present
      expect(
        find.textContaining(
            'CropGuard identifies known crop leaf diseases from photos'),
        findsOneWidget,
      );

      // Verify treatment advisory disclaimer is present
      expect(
        find.textContaining(
            "Treatment recommendations are advisory and not a substitute for an agricultural extension officer's guidance."),
        findsOneWidget,
      );
    });

    testWidgets('2. LowConfidenceScreen displays persistent scope disclaimer',
        (tester) async {
      when(() => mockHomeProvider.weeklyRisks).thenReturn([]);
      when(() => mockHomeProvider.weather).thenReturn(null);
      when(() => mockHomeProvider.outbreaks).thenReturn([]);

      await tester.pumpWidget(
        buildTestApp(
          child: const LowConfidenceScreen(
            confidence: 0.55,
            imagePath: '',
            topCandidates: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify scope disclaimer is present
      expect(
        find.textContaining(
            'CropGuard identifies known crop leaf diseases from photos'),
        findsOneWidget,
      );
    });

    testWidgets(
        '3. DiseaseLibraryScreen displays treatment advisory when viewing disease details',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(child: const DiseaseLibraryScreen()),
      );
      await tester.pumpAndSettle();

      // Tap the first disease item in the list
      await tester.tap(find.text('Apple Scab'));
      await tester.pumpAndSettle();

      // Verify treatment advisory disclaimer appears in the detail modal
      expect(
        find.textContaining(
            "Treatment recommendations are advisory and not a substitute for an agricultural extension officer's guidance."),
        findsOneWidget,
      );
    });

    testWidgets(
        '4. ChemicalDosageCalculatorScreen displays treatment advisory disclaimer',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(child: const ChemicalDosageCalculatorScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            "Treatment recommendations are advisory and not a substitute for an agricultural extension officer's guidance."),
        findsOneWidget,
      );
    });

    testWidgets(
        '5. TreatmentTrackerScreen displays treatment advisory disclaimer on plan cards',
        (tester) async {
      final dummyPlan = TreatmentPlan(
        id: '1',
        userId: 'test_user',
        detectionId: 1,
        cropType: 'Tomato',
        diseaseName: 'Late Blight',
        step: 'Apply copper fungicide spray',
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
        completed: false,
      );

      when(() => mockDatabaseHelper.getAllTreatments(
          userId: any(named: 'userId'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'))).thenAnswer((_) async => [dummyPlan]);
      when(() => mockDatabaseHelper.getPendingTreatmentsCount(
          userId: any(named: 'userId'))).thenAnswer((_) async => 1);
      when(() => mockDatabaseHelper.getCompletedTreatmentsCount(
          userId: any(named: 'userId'))).thenAnswer((_) async => 0);

      final trackerProvider = TreatmentTrackerProvider(
        mockDatabaseHelper,
        mockAuthRepo,
        mockSupabaseDatabaseService,
      );

      await tester.pumpWidget(
        buildTestApp(
          trackerProvider: trackerProvider,
          child: const TreatmentTrackerScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            "Treatment recommendations are advisory and not a substitute for an agricultural extension officer's guidance."),
        findsOneWidget,
      );
    });
  });
}
