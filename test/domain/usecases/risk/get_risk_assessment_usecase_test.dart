import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/models/risk_assessment.dart';
import 'package:cropguard_flutter/domain/repositories/i_risk_repository.dart';
import 'package:cropguard_flutter/domain/usecases/risk/get_risk_assessment_usecase.dart';

class MockRiskRepository extends Mock implements IRiskRepository {}

void main() {
  late MockRiskRepository mockRepository;
  late GetRiskAssessmentUseCase useCase;

  setUp(() {
    mockRepository = MockRiskRepository();
    useCase = GetRiskAssessmentUseCase(mockRepository);
  });

  final dummyAssessment = RiskAssessment(
    region: 'Ashanti',
    latitude: 6.6666,
    longitude: -1.6163,
    cropType: 'Maize',
    riskLevel: RiskLevel.moderate,
    confidence: RiskConfidence.medium,
    contributingFactors: ['4 verified outbreak reports nearby'],
    computedAt: DateTime.now(),
  );

  test('should return RiskAssessment from repository when call is successful',
      () async {
    when(() => mockRepository.getRiskForLocation(
          lat: 6.6666,
          lon: -1.6163,
          cropType: 'Maize',
        )).thenAnswer((_) async => Result.success(dummyAssessment));

    final result = await useCase(
      lat: 6.6666,
      lon: -1.6163,
      cropType: 'Maize',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.region, equals('Ashanti'));
    expect(result.data?.riskLevel, equals(RiskLevel.moderate));
    verify(() => mockRepository.getRiskForLocation(
          lat: 6.6666,
          lon: -1.6163,
          cropType: 'Maize',
        )).called(1);
  });
}
