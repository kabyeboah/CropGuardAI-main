import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:cropguard_flutter/core/utils/agri_weather_utils.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/data/remote/gemini_cloud_ai_service.dart';
import 'package:cropguard_flutter/domain/models/cloud_ai_analysis_result.dart';
import 'package:cropguard_flutter/domain/models/disease_risk.dart';
import 'package:cropguard_flutter/domain/models/weather_forecast.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/home/home_provider.dart';
import 'package:cropguard_flutter/presentation/screens/result/low_confidence_screen.dart';
import 'package:cropguard_flutter/presentation/screens/scanner/scanner_provider.dart';

class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class MockGeminiCloudAiService extends Mock implements GeminiCloudAiService {}

class MockCommunityRepository extends Mock implements ICommunityRepository {}

class MockScannerProvider extends Mock implements ScannerProvider {}

class MockHomeProvider extends Mock implements HomeProvider {}

void main() {
  final sl = GetIt.instance;
  late MockFirebaseAuthService mockAuthService;
  late MockGeminiCloudAiService mockGeminiService;
  late MockCommunityRepository mockCommunityRepo;
  late MockScannerProvider mockScannerProvider;
  late MockHomeProvider mockHomeProvider;

  setUp(() {
    sl.reset();
    mockAuthService = MockFirebaseAuthService();
    mockGeminiService = MockGeminiCloudAiService();
    mockCommunityRepo = MockCommunityRepository();
    mockScannerProvider = MockScannerProvider();
    mockHomeProvider = MockHomeProvider();

    sl.registerSingleton<FirebaseAuthService>(mockAuthService);
    sl.registerSingleton<GeminiCloudAiService>(mockGeminiService);
    sl.registerSingleton<ICommunityRepository>(mockCommunityRepo);

    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockAuthService.currentUserId).thenReturn('');
    when(() => mockGeminiService.analyzeCropImage(
          imagePath: any(named: 'imagePath'),
          cropType: any(named: 'cropType'),
          initialTopCandidates: any(named: 'initialTopCandidates'),
        )).thenAnswer((_) async => const CloudAiAnalysisResult(
          label: 'Tomato Late Blight',
          confidence: 0.94,
          isHealthy: false,
          symptoms: ['Dark lesions'],
          rootCause: 'Phytophthora infestans',
          organicRemedies: ['Copper spray'],
          preventionTips: ['Proper spacing'],
          rawReasoning: 'Observed lesions',
        ));
  });

  tearDown(() {
    sl.reset();
  });

  Widget buildWidget({
    required Widget child,
    HomeProvider? homeProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScannerProvider>.value(
            value: mockScannerProvider),
        ChangeNotifierProvider<HomeProvider>.value(
          value: homeProvider ?? mockHomeProvider,
        ),
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

  group('LowConfidenceScreen Regional Risk Integration', () {
    testWidgets(
        'does not apply fake hardcoded Black Pod risk when regionalRisks is empty',
        (tester) async {
      when(() => mockHomeProvider.weeklyRisks).thenReturn([]);
      when(() => mockHomeProvider.weather).thenReturn(null);
      when(() => mockHomeProvider.outbreaks).thenReturn([]);

      final candidates = [
        (label: 'Tomato___Late_blight', confidence: 0.50),
        (label: 'Cocoa___Black_pod_rot', confidence: 0.30),
        (label: 'Tomato___Healthy', confidence: 0.20),
      ];

      await tester.pumpWidget(
        buildWidget(
          child: LowConfidenceScreen(
            confidence: 0.50,
            imagePath: '/fake/path.jpg',
            topCandidates: candidates,
            regionalRisks: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand on-device ExpansionTile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Verify that Tomato Late blight remains the top candidate (not displaced by fake Black Pod boost)
      expect(find.textContaining('Late blight'), findsWidgets);
      expect(find.byType(LowConfidenceScreen), findsOneWidget);
    });

    testWidgets(
        'uses real regional risks passed in constructor to boost matching candidates',
        (tester) async {
      final candidates = [
        (label: 'Tomato___Late_blight', confidence: 0.40),
        (label: 'Tomato___Early_blight', confidence: 0.35),
        (label: 'Tomato___Healthy', confidence: 0.25),
      ];

      final realRisks = [
        const DiseaseRisk(
          type: DiseaseRiskType.lateBlight,
          level: RiskLevel.high,
          humidity: 90,
          temp: 22,
          hasNearbyOutbreak: true,
        ),
      ];

      await tester.pumpWidget(
        buildWidget(
          child: LowConfidenceScreen(
            confidence: 0.40,
            imagePath: '/fake/path.jpg',
            topCandidates: candidates,
            regionalRisks: realRisks,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand on-device ExpansionTile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.byType(LowConfidenceScreen), findsOneWidget);
      expect(find.textContaining('Late blight'), findsWidgets);
    });

    testWidgets(
        'computes regional risks from HomeProvider weather & verified outbreaks when not passed explicitly',
        (tester) async {
      final mockDaily = [
        DailyForecast(
          date: DateTime.now(),
          weatherCode: 61,
          maxTemp: 22.0,
          minTemp: 18.0,
          precipitationProbability: 80.0,
          humidity: 92.0,
        ),
      ];

      final mockForecast = WeatherForecast(
        latitude: 6.6666,
        longitude: -1.6163,
        daily: mockDaily,
      );

      final mockOutbreaks = [
        {
          'disease': 'late blight',
          'region': 'South',
          'verifiedBy': ['u1', 'u2', 'u3'],
          'refutedBy': <String>[],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      ];

      final evaluatedRisks = AgriWeatherUtils.assessWeeklyRisks(
        mockDaily,
        outbreaks: mockOutbreaks,
        region: 'South',
      );

      when(() => mockHomeProvider.weeklyRisks).thenReturn(evaluatedRisks);
      when(() => mockHomeProvider.weather).thenReturn(mockForecast);
      when(() => mockHomeProvider.outbreaks).thenReturn(mockOutbreaks);

      final candidates = [
        (label: 'Tomato___Late_blight', confidence: 0.38),
        (label: 'Cocoa___Black_pod_rot', confidence: 0.35),
        (label: 'Tomato___Healthy', confidence: 0.27),
      ];

      await tester.pumpWidget(
        buildWidget(
          child: LowConfidenceScreen(
            confidence: 0.38,
            imagePath: '/fake/path.jpg',
            topCandidates: candidates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand on-device ExpansionTile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.byType(LowConfidenceScreen), findsOneWidget);
      expect(find.textContaining('Late blight'), findsWidgets);
    });

    testWidgets(
        'does not display fake fallback candidates when topCandidates is empty',
        (tester) async {
      when(() => mockHomeProvider.weeklyRisks).thenReturn([]);
      when(() => mockHomeProvider.weather).thenReturn(null);
      when(() => mockHomeProvider.outbreaks).thenReturn([]);

      await tester.pumpWidget(
        buildWidget(
          child: const LowConfidenceScreen(
            confidence: 0.30,
            imagePath: '/fake/path.jpg',
            topCandidates: [],
            regionalRisks: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand on-device ExpansionTile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.byType(LowConfidenceScreen), findsOneWidget);
      expect(find.textContaining('Black pod rot'), findsNothing);
      expect(find.textContaining('Frosty pod rot'), findsNothing);
    });

    testWidgets(
        'auto-triggers Cloud AI diagnosis and displays persistent scope disclaimer',
        (tester) async {
      when(() => mockHomeProvider.weeklyRisks).thenReturn([]);
      when(() => mockHomeProvider.weather).thenReturn(null);
      when(() => mockHomeProvider.outbreaks).thenReturn([]);

      await tester.pumpWidget(
        buildWidget(
          child: const LowConfidenceScreen(
            confidence: 0.45,
            imagePath: '/fake/path.jpg',
            topCandidates: [(label: 'Tomato___Early_blight', confidence: 0.45)],
            regionalRisks: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Cloud AI recommendation card
      expect(find.text('Gemini Cloud AI Recommended'), findsOneWidget);
      expect(find.text('Tomato Late Blight'), findsOneWidget);
      expect(find.text('Accept & Save Cloud Diagnosis'), findsOneWidget);

      // Verify persistent scope disclaimer
      expect(
        find.textContaining(
            'CropGuard identifies known crop leaf diseases from photos'),
        findsOneWidget,
      );

      // Verify on-device section is present
      expect(
          find.textContaining('On-Device Preliminary Guess'), findsOneWidget);
    });
  });
}
