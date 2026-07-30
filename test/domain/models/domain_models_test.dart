import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/domain/models/app_notification.dart';
import 'package:cropguard_flutter/domain/models/disease_risk.dart';
import 'package:cropguard_flutter/domain/models/field.dart';
import 'package:cropguard_flutter/domain/models/weather_forecast.dart';

void main() {
  // ── AppNotification ───────────────────────────────────────────────────────

  group('AppNotification', () {
    final now = DateTime(2024, 5, 1, 10, 30);

    final notification = AppNotification(
      id: 'n1',
      title: 'Outbreak Alert',
      body: 'Cassava Mosaic nearby',
      type: 'outbreak',
      isRead: false,
      createdAt: now,
    );

    test('toMap encodes all fields correctly', () {
      final map = notification.toMap();
      expect(map['id'], 'n1');
      expect(map['title'], 'Outbreak Alert');
      expect(map['body'], 'Cassava Mosaic nearby');
      expect(map['type'], 'outbreak');
      expect(map['isRead'], 0); // false → 0
      expect(map['createdAtMs'], now.millisecondsSinceEpoch);
    });

    test('fromMap reconstructs the notification correctly', () {
      final map = notification.toMap();
      final restored = AppNotification.fromMap(map);
      expect(restored.id, 'n1');
      expect(restored.title, 'Outbreak Alert');
      expect(restored.isRead, isFalse);
      expect(restored.createdAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
    });

    test('copyWith only changes isRead', () {
      final read = notification.copyWith(isRead: true);
      expect(read.isRead, isTrue);
      expect(read.title, notification.title);
      expect(read.id, notification.id);
    });

    test('fromMap defaults type to info when missing', () {
      final map = {
        'id': '2',
        'title': 'T',
        'body': 'B',
        'isRead': 0,
        'createdAtMs': 0,
      };
      final n = AppNotification.fromMap(map);
      expect(n.type, 'info');
    });

    test('isRead true encodes as 1 in toMap', () {
      final read = notification.copyWith(isRead: true);
      expect(read.toMap()['isRead'], 1);
    });
  });

  // ── DiseaseRisk ───────────────────────────────────────────────────────────

  group('DiseaseRisk', () {
    test('can be constructed with all fields', () {
      const risk = DiseaseRisk(
        type: DiseaseRiskType.lateBlight,
        level: RiskLevel.high,
        humidity: 88,
        temp: 22,
        hasNearbyOutbreak: true,
      );
      expect(risk.type, DiseaseRiskType.lateBlight);
      expect(risk.level, RiskLevel.high);
      expect(risk.hasNearbyOutbreak, isTrue);
    });

    test('hasNearbyOutbreak defaults to false', () {
      const risk = DiseaseRisk(
        type: DiseaseRiskType.riceBlast,
        level: RiskLevel.moderate,
        humidity: 75,
        temp: 28,
      );
      expect(risk.hasNearbyOutbreak, isFalse);
    });

    test('all DiseaseRiskType values are distinct', () {
      final types = DiseaseRiskType.values.toSet();
      expect(types.length, DiseaseRiskType.values.length);
    });

    test('all RiskLevel values are distinct', () {
      final levels = RiskLevel.values.toSet();
      expect(levels.length, RiskLevel.values.length);
    });
  });

  // ── Field ─────────────────────────────────────────────────────────────────

  group('Field', () {
    test('getHarvestDurationDays returns correct value for known crops', () {
      expect(
        const Field(id: '1', name: 'F', cropType: 'Maize', sizeHectares: 1)
            .getHarvestDurationDays(),
        90,
      );
      expect(
        const Field(id: '1', name: 'F', cropType: 'Cassava', sizeHectares: 1)
            .getHarvestDurationDays(),
        300,
      );
      expect(
        const Field(id: '1', name: 'F', cropType: 'Rice', sizeHectares: 1)
            .getHarvestDurationDays(),
        120,
      );
      expect(
        const Field(id: '1', name: 'F', cropType: 'Tomato', sizeHectares: 1)
            .getHarvestDurationDays(),
        70,
      );
      expect(
        const Field(id: '1', name: 'F', cropType: 'Yam', sizeHectares: 1)
            .getHarvestDurationDays(),
        240,
      );
    });

    test('getHarvestDurationDays defaults to 90 for unknown crop', () {
      expect(
        const Field(id: '1', name: 'F', cropType: 'Mango', sizeHectares: 1)
            .getHarvestDurationDays(),
        90,
      );
    });

    test('getDaysRemaining returns null when plantingDate is null', () {
      const field = Field(
          id: '1', name: 'F', cropType: 'Maize', sizeHectares: 1);
      expect(field.getDaysRemaining(), isNull);
    });

    test('getDaysRemaining returns 0 when harvest date has passed', () {
      final oldDate = DateTime.now()
          .subtract(const Duration(days: 200))
          .millisecondsSinceEpoch;
      final field = Field(
        id: '1',
        name: 'F',
        cropType: 'Maize',
        sizeHectares: 1,
        plantingDate: oldDate,
      );
      expect(field.getDaysRemaining(), 0);
    });

    test('getDaysRemaining returns positive value for future harvest', () {
      final recent = DateTime.now()
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch;
      final field = Field(
        id: '1',
        name: 'F',
        cropType: 'Maize',
        sizeHectares: 1,
        plantingDate: recent,
      );
      // 90 - 10 = 80 days remaining (approximately)
      expect(field.getDaysRemaining(), greaterThan(0));
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      const field = Field(
        id: 'f42',
        name: 'North Plot',
        cropType: 'Rice',
        sizeHectares: 2.5,
        plantingDate: 1_700_000_000_000,
        userId: 'u99',
      );
      final restored = Field.fromMap(field.toMap());
      expect(restored.id, 'f42');
      expect(restored.name, 'North Plot');
      expect(restored.cropType, 'Rice');
      expect(restored.sizeHectares, 2.5);
      expect(restored.plantingDate, 1_700_000_000_000);
      expect(restored.userId, 'u99');
    });
  });

  // ── WeatherForecast ───────────────────────────────────────────────────────

  group('WeatherForecast', () {
    test('fromJson parses a valid API response', () {
      final json = {
        'latitude': 5.56,
        'longitude': -0.20,
        'daily': {
          'time': ['2024-06-01', '2024-06-02'],
          'temperature_2m_max': [32.0, 30.5],
          'temperature_2m_min': [24.0, 23.0],
          'precipitation_probability_max': [60.0, 80.0],
          'relative_humidity_2m_max': [85.0, 90.0],
          'weather_code': [61, 0],
        },
      };
      final forecast = WeatherForecast.fromJson(json);
      expect(forecast.latitude, 5.56);
      expect(forecast.daily, hasLength(2));
      expect(forecast.daily.first.maxTemp, 32.0);
      expect(forecast.daily.last.weatherCode, 0);
    });

    test('fromJson handles integer temperature values (no type error)', () {
      final json = {
        'latitude': 5,
        'longitude': -0,
        'daily': {
          'time': ['2024-06-01'],
          'temperature_2m_max': [32], // int, not double
          'temperature_2m_min': [24],
          'precipitation_probability_max': [70],
          'relative_humidity_2m_max': [85],
          'weather_code': [61],
        },
      };
      expect(() => WeatherForecast.fromJson(json), returnsNormally);
    });

    test('toJson / fromJson round-trip preserves key fields', () {
      final original = WeatherForecast(
        latitude: 7.9,
        longitude: -1.0,
        daily: [
          DailyForecast(
            date: DateTime(2024, 6, 1),
            maxTemp: 33.0,
            minTemp: 25.0,
            precipitationProbability: 50.0,
            humidity: 78.0,
            weatherCode: 3,
          ),
        ],
      );
      final restored = WeatherForecast.fromJson(original.toJson());
      expect(restored.latitude, original.latitude);
      expect(restored.daily.first.maxTemp, 33.0);
      expect(restored.daily.first.weatherCode, 3);
    });
  });

  // ── DailyForecast.weatherIcon / weatherDescription ────────────────────────

  group('DailyForecast icons and descriptions', () {
    DailyForecast day(int code) => DailyForecast(
          date: DateTime(2024),
          maxTemp: 30,
          minTemp: 22,
          precipitationProbability: 0,
          humidity: 60,
          weatherCode: code,
        );

    test('weatherCode 0 → clear sky emoji', () {
      expect(day(0).weatherIcon, '☀️');
      expect(day(0).weatherDescription, 'Clear sky');
    });

    test('weatherCode 61 → rainy emoji', () {
      expect(day(61).weatherIcon, '🌧️');
      expect(day(61).weatherDescription, 'Rainy');
    });

    test('weatherCode 95 → thunderstorm emoji', () {
      expect(day(95).weatherIcon, '⛈️');
      expect(day(95).weatherDescription, 'Thunderstorm');
    });
  });
}
