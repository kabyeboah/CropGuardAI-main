import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/agri_weather_utils.dart';
import 'package:cropguard_flutter/domain/models/weather_forecast.dart';
import 'package:cropguard_flutter/domain/models/disease_risk.dart';

void main() {
  group('AgriWeatherUtils Disease Risk Integration Tests', () {
    final List<DailyForecast> dailyForecasts = [
      DailyForecast(
        date: DateTime.now(),
        maxTemp: 22.0,
        minTemp: 18.0,
        humidity: 60.0, // Low humidity, usually won't trigger late blight
        precipitationProbability: 10.0,
        weatherCode: 1,
      ),
      DailyForecast(
        date: DateTime.now().add(const Duration(days: 1)),
        maxTemp: 23.0,
        minTemp: 17.0,
        humidity: 55.0,
        precipitationProbability: 15.0,
        weatherCode: 1,
      ),
      DailyForecast(
        date: DateTime.now().add(const Duration(days: 2)),
        maxTemp: 24.0,
        minTemp: 18.0,
        humidity: 58.0,
        precipitationProbability: 12.0,
        weatherCode: 1,
      ),
    ];

    test(
        'should return empty risks when weather is clear and no outbreaks exist',
        () {
      final risks = AgriWeatherUtils.assessWeeklyRisks(
        dailyForecasts,
        outbreaks: [],
        region: 'Ashanti',
      );

      expect(risks, isEmpty);
    });

    test(
        'should upgrade risk level and set hasNearbyOutbreak to true when outbreak is verified in the region',
        () {
      // 1. Arrange a mock outbreak that matches Tomato Late Blight, in 'Ashanti' region, verified (3 votes), less than 14 days old
      final verifiedOutbreak = {
        'id': 'outbreak_123',
        'disease': 'Tomato Late Blight',
        'region': 'Ashanti',
        'verifiedBy': ['user1', 'user2', 'user3'],
        'refutedBy': [],
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      };

      // 2. Act
      final risks = AgriWeatherUtils.assessWeeklyRisks(
        dailyForecasts,
        outbreaks: [verifiedOutbreak],
        region: 'Ashanti',
      );

      // 3. Assert
      // Late Blight should be added due to nearby verified outbreak, even if humidity was low.
      final blightRisk =
          risks.firstWhere((r) => r.type == DiseaseRiskType.lateBlight);
      expect(blightRisk, isNotNull);
      expect(
          blightRisk.level,
          equals(RiskLevel
              .moderate)); // Weather clear + outbreak present yields moderate
      expect(blightRisk.hasNearbyOutbreak, isTrue);
    });

    test('should ignore outbreaks from other regions or unverified outbreaks',
        () {
      final unverifiedOutbreak = {
        'id': 'outbreak_456',
        'disease': 'Tomato Late Blight',
        'region': 'Ashanti',
        'verifiedBy': ['user1'], // Only 1 verification
        'refutedBy': [],
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      };

      final differentRegionOutbreak = {
        'id': 'outbreak_789',
        'disease': 'Tomato Late Blight',
        'region': 'Northern', // Other region
        'verifiedBy': ['user1', 'user2', 'user3'],
        'refutedBy': [],
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      };

      final risks = AgriWeatherUtils.assessWeeklyRisks(
        dailyForecasts,
        outbreaks: [unverifiedOutbreak, differentRegionOutbreak],
        region: 'Ashanti',
      );

      expect(risks, isEmpty);
    });
  });
}
