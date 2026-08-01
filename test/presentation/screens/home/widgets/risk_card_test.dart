import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/utils/location_helper.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/models/risk_assessment.dart';
import 'package:cropguard_flutter/domain/usecases/risk/get_risk_assessment_usecase.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/home/widgets/risk_card.dart';

class MockGetRiskAssessmentUseCase extends Mock implements GetRiskAssessmentUseCase {}

void main() {
  late MockGetRiskAssessmentUseCase mockUseCase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockUseCase = MockGetRiskAssessmentUseCase();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  testWidgets('RiskCard displays risk level and contributing factors when loaded', (tester) async {
    final dummyAssessment = RiskAssessment(
      region: 'Ashanti',
      latitude: 6.6666,
      longitude: -1.6163,
      cropType: 'Maize',
      riskLevel: RiskLevel.high,
      confidence: RiskConfidence.high,
      contributingFactors: [
        '5 verified outbreak reports nearby',
        'High humidity favors fungal spread',
      ],
      computedAt: DateTime.now(),
    );

    when(() => mockUseCase.call(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          cropType: any(named: 'cropType'),
        )).thenAnswer((_) async => Result.success(dummyAssessment));

    await tester.pumpWidget(buildTestableWidget(
      RiskCard(
        cropType: 'Maize',
        location: const GeoPoint(6.6666, -1.6163),
        getRiskAssessmentUseCase: mockUseCase,
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Outbreak Risk Forecast'), findsOneWidget);
    expect(find.textContaining('High'), findsAtLeastNWidgets(1));
    expect(find.text('5 verified outbreak reports nearby'), findsOneWidget);
  });

  testWidgets('RiskCard displays insufficient data message when local reports < 3', (tester) async {
    final insufficientAssessment = RiskAssessment(
      region: 'Bono',
      latitude: 7.5828,
      longitude: -1.9394,
      cropType: 'Cassava',
      riskLevel: RiskLevel.none,
      confidence: RiskConfidence.insufficientData,
      contributingFactors: ['Insufficient local outbreak report data'],
      computedAt: DateTime.now(),
    );

    when(() => mockUseCase.call(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          cropType: any(named: 'cropType'),
        )).thenAnswer((_) async => Result.success(insufficientAssessment));

    await tester.pumpWidget(buildTestableWidget(
      RiskCard(
        cropType: 'Cassava',
        location: const GeoPoint(7.5828, -1.9394),
        getRiskAssessmentUseCase: mockUseCase,
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Outbreak Risk Forecast'), findsOneWidget);
    expect(find.text('No Elevated Risk'), findsOneWidget);
    expect(find.textContaining('Insufficient'), findsAtLeastNWidgets(1));
  });
}
