import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/data/repositories/risk_repository_impl.dart';
import 'package:cropguard_flutter/domain/models/risk_assessment.dart';
import 'package:cropguard_flutter/domain/models/weather_forecast.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_weather_repository.dart';

class MockCommunityRepository extends Mock implements ICommunityRepository {}
class MockWeatherRepository extends Mock implements IWeatherRepository {}

void main() {
  late MockCommunityRepository mockCommunityRepo;
  late MockWeatherRepository mockWeatherRepo;
  late RiskRepositoryImpl riskRepository;

  setUp(() {
    mockCommunityRepo = MockCommunityRepository();
    mockWeatherRepo = MockWeatherRepository();
    riskRepository = RiskRepositoryImpl(mockCommunityRepo, mockWeatherRepo);
  });

  group('RiskRepositoryImpl Guardrails & Scoring Tests', () {
    test('insufficient-data guardrail: returns confidence insufficientData and riskLevel none when non-seed reports < 3', () async {
      // Mock community repo returning only 2 real non-seed reports
      final twoReports = [
        {
          'id': 'real_1',
          'isSeed': false,
          'source': 'community',
          'disease': 'Maize Common Rust',
          'region': 'Ashanti',
          'latitude': 6.6666,
          'longitude': -1.6163,
          'reportedAt': DateTime.now().toIso8601String(),
          'verifiedBy': ['u1', 'u2'],
          'refutedBy': [],
        },
        {
          'id': 'real_2',
          'isSeed': false,
          'source': 'community',
          'disease': 'Maize Common Rust',
          'region': 'Ashanti',
          'latitude': 6.6700,
          'longitude': -1.6200,
          'reportedAt': DateTime.now().toIso8601String(),
          'verifiedBy': ['u1'],
          'refutedBy': [],
        },
      ];

      when(() => mockCommunityRepo.getOutbreakReports())
          .thenAnswer((_) async => Result.success(twoReports));

      final result = await riskRepository.getRiskForLocation(
        lat: 6.6666,
        lon: -1.6163,
        cropType: 'Maize',
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.data!;
      expect(assessment.confidence, equals(RiskConfidence.insufficientData));
      expect(assessment.riskLevel, equals(RiskLevel.none));
      expect(assessment.isInsufficientData, isTrue);
      expect(assessment.contributingFactors.first, contains('Insufficient local outbreak report data'));

      // Verify weather repo was NOT queried because guardrail short-circuited early
      verifyNever(() => mockWeatherRepo.getWeatherForecast(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ));
    });

    test('seed-data-exclusion guardrail: excludes seed-sourced entries completely from computation', () async {
      // 5 seed reports + 1 real report. Total reports = 6, but non-seed count = 1.
      final mixedReports = [
        {
          'id': 'seed_ob_1',
          'isSeed': true,
          'source': 'seed',
          'disease': 'Cocoa Black Pod Rot',
          'region': 'Ashanti',
          'latitude': 6.6666,
          'longitude': -1.6163,
          'reportedAt': DateTime.now().toIso8601String(),
          'verifiedBy': ['u1', 'u2', 'u3', 'u4', 'u5'],
        },
        {
          'id': 'seed_ob_2',
          'isSeed': true,
          'source': 'seed',
          'disease': 'Cassava Mosaic Disease',
          'region': 'Ashanti',
          'latitude': 6.6666,
          'longitude': -1.6163,
          'reportedAt': DateTime.now().toIso8601String(),
          'verifiedBy': ['u1', 'u2'],
        },
        {
          'id': 'seed_ob_3',
          'isSeed': true,
          'source': 'seed',
          'disease': 'Maize Common Rust',
          'region': 'Ashanti',
          'latitude': 6.6666,
          'longitude': -1.6163,
          'reportedAt': DateTime.now().toIso8601String(),
        },
        {
          'id': 'real_report_1',
          'isSeed': false,
          'source': 'community',
          'disease': 'Maize Common Rust',
          'region': 'Ashanti',
          'latitude': 6.6666,
          'longitude': -1.6163,
          'reportedAt': DateTime.now().toIso8601String(),
          'verifiedBy': ['u1'],
        },
      ];

      when(() => mockCommunityRepo.getOutbreakReports())
          .thenAnswer((_) async => Result.success(mixedReports));

      final result = await riskRepository.getRiskForLocation(
        lat: 6.6666,
        lon: -1.6163,
        cropType: 'Maize',
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.data!;
      // Should hit insufficient-data guardrail because valid non-seed count is 1 (< 3)
      expect(assessment.confidence, equals(RiskConfidence.insufficientData));
      expect(assessment.riskLevel, equals(RiskLevel.none));
    });

    test('happy path: computes elevated risk score when >= 3 non-seed reports exist with favorable weather', () async {
      final validReports = List.generate(4, (i) => {
        'id': 'real_ob_$i',
        'isSeed': false,
        'source': 'community',
        'disease': 'Tomato Late Blight',
        'cropType': 'Tomato',
        'region': 'Ashanti',
        'latitude': 6.6666 + (i * 0.01),
        'longitude': -1.6163 + (i * 0.01),
        'reportedAt': DateTime.now().toIso8601String(),
        'verifiedBy': ['u1', 'u2', 'u3'],
        'refutedBy': [],
      });

      final dummyForecast = WeatherForecast(
        latitude: 6.6666,
        longitude: -1.6163,
        daily: [
          DailyForecast(
            date: DateTime.now(),
            maxTemp: 24.0,
            minTemp: 18.0,
            precipitationProbability: 80.0,
            humidity: 88.0,
            weatherCode: 61,
          ),
          DailyForecast(
            date: DateTime.now().add(const Duration(days: 1)),
            maxTemp: 25.0,
            minTemp: 19.0,
            precipitationProbability: 75.0,
            humidity: 85.0,
            weatherCode: 61,
          ),
        ],
      );

      when(() => mockCommunityRepo.getOutbreakReports())
          .thenAnswer((_) async => Result.success(validReports));
      when(() => mockWeatherRepo.getWeatherForecast(latitude: 6.6666, longitude: -1.6163))
          .thenAnswer((_) async => dummyForecast);

      final result = await riskRepository.getRiskForLocation(
        lat: 6.6666,
        lon: -1.6163,
        cropType: 'Tomato',
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.data!;
      expect(assessment.riskLevel, isNot(equals(RiskLevel.none)));
      expect(assessment.confidence, isNot(equals(RiskConfidence.insufficientData)));
      expect(assessment.contributingFactors.any((f) => f.contains('verified outbreak reports')), isTrue);
      expect(assessment.contributingFactors.any((f) => f.contains('fungal pathogen spread')), isTrue);
    });
  });
}
