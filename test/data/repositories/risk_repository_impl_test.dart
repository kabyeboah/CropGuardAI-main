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

  group('RiskRepositoryImpl Guardrails & Weather Fallback Tests', () {
    test(
        'weather microclimate fallback: returns confidence low and weather risk score when non-seed reports < 3 but weather is available',
        () async {
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
      ];

      final dummyForecast = WeatherForecast(
        latitude: 6.6666,
        longitude: -1.6163,
        daily: [
          DailyForecast(
            date: DateTime.now(),
            maxTemp: 26.0,
            minTemp: 20.0,
            precipitationProbability: 80.0,
            humidity: 82.0,
            weatherCode: 61,
          ),
        ],
      );

      when(() => mockCommunityRepo.getOutbreakReports())
          .thenAnswer((_) async => Result.success(twoReports));
      when(() => mockWeatherRepo.getWeatherForecast(
          latitude: 6.6666,
          longitude: -1.6163)).thenAnswer((_) async => dummyForecast);

      final result = await riskRepository.getRiskForLocation(
        lat: 6.6666,
        lon: -1.6163,
        cropType: 'Maize',
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.data!;
      expect(assessment.confidence, equals(RiskConfidence.low));
      expect(assessment.riskLevel, equals(RiskLevel.high));
      expect(
          assessment.contributingFactors
              .any((f) => f.contains('microclimate weather data')),
          isTrue);
      expect(
          assessment.contributingFactors
              .any((f) => f.contains('fungal pathogen spread')),
          isTrue);
    });

    test(
        'insufficient-data fallback: returns confidence insufficientData when reports < 3 AND weather forecast fails',
        () async {
      when(() => mockCommunityRepo.getOutbreakReports())
          .thenAnswer((_) async => Result.success([]));
      when(() => mockWeatherRepo.getWeatherForecast(
          latitude: 6.6666,
          longitude: -1.6163)).thenThrow(Exception('Weather service offline'));

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
    });

    test(
        'seed-data-exclusion: excludes seed-sourced entries from crowd density calculation',
        () async {
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
      when(() => mockWeatherRepo.getWeatherForecast(
          latitude: 6.6666,
          longitude: -1.6163)).thenThrow(Exception('No weather'));

      final result = await riskRepository.getRiskForLocation(
        lat: 6.6666,
        lon: -1.6163,
        cropType: 'Maize',
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.data!;
      // Should exclude seed report, leaving 1 report, and with weather failing, returns insufficientData
      expect(assessment.confidence, equals(RiskConfidence.insufficientData));
      expect(assessment.riskLevel, equals(RiskLevel.none));
    });

    test(
        'happy path: computes elevated risk score when >= 3 non-seed reports exist with favorable weather',
        () async {
      final validReports = List.generate(
          4,
          (i) => {
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
      when(() => mockWeatherRepo.getWeatherForecast(
          latitude: 6.6666,
          longitude: -1.6163)).thenAnswer((_) async => dummyForecast);

      final result = await riskRepository.getRiskForLocation(
        lat: 6.6666,
        lon: -1.6163,
        cropType: 'Tomato',
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.data!;
      expect(assessment.riskLevel, isNot(equals(RiskLevel.none)));
      expect(assessment.confidence,
          isNot(equals(RiskConfidence.insufficientData)));
      expect(
          assessment.contributingFactors
              .any((f) => f.contains('verified outbreak reports')),
          isTrue);
      expect(
          assessment.contributingFactors
              .any((f) => f.contains('fungal pathogen spread')),
          isTrue);
    });
  });
}
