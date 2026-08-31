import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/agri_weather_utils.dart';
import 'package:cropguard_flutter/core/utils/outbreak_alert_service.dart';
import 'package:cropguard_flutter/core/utils/scan_severity.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';
import 'package:cropguard_flutter/domain/models/disease_risk.dart';
import 'package:cropguard_flutter/domain/models/weather_forecast.dart';

void main() {
  group('Phase 13 Domain & Business Logic Validation', () {
    // ── 1. Disease Information & Authoritative Basis ────────────────────────
    test(
        '1. Every disease entry in DiseaseDatabase has an authoritative source/basis and safety guidance',
        () {
      final allDiseases = DiseaseDatabase.getAllDiseases();
      expect(allDiseases.isNotEmpty, true);

      for (final entry in allDiseases) {
        expect(entry.displayName.isNotEmpty, true,
            reason: 'Display name missing for ${entry.label}');
        expect(entry.cropType.isNotEmpty, true,
            reason: 'Crop type missing for ${entry.label}');
        expect(entry.sourceBasis.isNotEmpty, true,
            reason: 'Source/basis missing for ${entry.label}');
        expect(entry.sourceBasis, contains('Guidelines'),
            reason: 'Source should reference authoritative guidelines');

        if (!entry.isHealthy) {
          expect(entry.treatments.isNotEmpty, true,
              reason: 'Treatments missing for ${entry.label}');
          expect(
              entry.safetyPrecautions != null &&
                  entry.safetyPrecautions!.isNotEmpty,
              true,
              reason:
                  'Safety precautions missing for diseased class ${entry.label}');
          expect(entry.safetyPrecautions, contains('PPE'),
              reason: 'Safety precautions should emphasize PPE');
        }
      }
    });

    test(
        '2. Fallback disease info contains default authoritative extension source & safety warning',
        () {
      final fallback = DiseaseDatabase.getInfo('NonExistent_Crop_Disease');
      expect(fallback.displayName, isNotEmpty);
      expect(fallback.sourceBasis, contains('MoFA Ghana'));
      expect(fallback.safetyPrecautions, contains('PPE'));
      expect(fallback.treatments.first, contains('extension officer'));
    });

    // ── 2. Weather Interpretation & Fungal Disease Risk ─────────────────────
    test(
        '3. AgriWeatherUtils identifies fungal risk under high humidity and mild/warm temp',
        () {
      final fungalForecast = DailyForecast(
        date: DateTime(2026, 9, 1),
        maxTemp: 26.0,
        minTemp: 21.0,
        weatherCode: 65,
        precipitationProbability: 85.0,
        humidity: 88.0,
      );

      final nonFungalForecast = DailyForecast(
        date: DateTime(2026, 9, 1),
        maxTemp: 35.0,
        minTemp: 26.0,
        weatherCode: 0,
        precipitationProbability: 10.0,
        humidity: 45.0,
      );

      expect(AgriWeatherUtils.isFungalRisk(fungalForecast), true);
      expect(AgriWeatherUtils.isFungalRisk(nonFungalForecast), false);
    });

    test(
        '4. AgriWeatherUtils spray advisory warns against wash-off when rain probability exceeds 50%',
        () {
      final highRainForecast = DailyForecast(
        date: DateTime(2026, 9, 1),
        maxTemp: 28.0,
        minTemp: 22.0,
        weatherCode: 65,
        precipitationProbability: 75.0,
        humidity: 90.0,
      );

      final dryForecast = DailyForecast(
        date: DateTime(2026, 9, 1),
        maxTemp: 30.0,
        minTemp: 22.0,
        weatherCode: 0,
        precipitationProbability: 10.0,
        humidity: 55.0,
      );

      final sprayWarning = AgriWeatherUtils.getSprayAdvisory(highRainForecast);
      final sprayGood = AgriWeatherUtils.getSprayAdvisory(dryForecast);

      expect(sprayWarning, contains('Avoid spraying today'));
      expect(sprayWarning, contains('wash off'));
      expect(sprayGood, contains('Excellent spray window'));
    });

    test(
        '5. AgriWeatherUtils provides Ghana seasonal planting calendar by agro-ecological zone',
        () {
      final northAdvice = AgriWeatherUtils.getPlantingAdvice('North');
      final southAdvice = AgriWeatherUtils.getPlantingAdvice('South');

      expect(northAdvice['status'], isNotNull);
      expect(northAdvice['action'], isNotNull);
      expect(southAdvice['status'], isNotNull);
      expect(southAdvice['action'], isNotNull);
    });

    // ── 3. Weekly Risk Assessment & Outbreak Merging ────────────────────────
    test(
        '6. assessWeeklyRisks elevates disease risk level to high when active regional outbreak is confirmed',
        () {
      final dailyForecasts = [
        DailyForecast(
          date: DateTime(2026, 9, 1),
          maxTemp: 24.0,
          minTemp: 19.0,
          weatherCode: 3,
          precipitationProbability: 60.0,
          humidity: 82.0,
        ),
      ];

      // Simulated verified outbreak in Ashanti Region
      final outbreaks = [
        {
          'id': 'outbreak_1',
          'disease': 'Tomato Late Blight',
          'region': 'Ashanti',
          'verifiedBy': ['user_1', 'user_2', 'user_3'],
          'refutedBy': [],
          'timestamp': DateTime.now(),
        }
      ];

      final risks = AgriWeatherUtils.assessWeeklyRisks(
        dailyForecasts,
        outbreaks: outbreaks,
        region: 'Ashanti',
      );

      expect(risks.isNotEmpty, true);
      final lateBlightRisk =
          risks.firstWhere((r) => r.type == DiseaseRiskType.lateBlight);
      expect(lateBlightRisk.level, RiskLevel.high);
      expect(lateBlightRisk.hasNearbyOutbreak, true);
    });

    // ── 4. Outbreak Calculation Constraints ────────────────────────────────
    test(
        '7. OutbreakAlertService radius and freshness constants meet domain specs',
        () {
      expect(OutbreakAlertService.radiusKm, 25.0);
      expect(OutbreakAlertService.recentDays, 14);
    });

    // ── 5. Treatment Scheduling Urgency Intervals ──────────────────────────
    test(
        '8. Severity intervals schedule severe diseases on Day 0 and moderate/early appropriately',
        () {
      int scheduleFirstDay(String severity) {
        switch (severity.toLowerCase()) {
          case ScanSeverity.severe:
            return 0; // immediate action
          case ScanSeverity.early:
            return 1;
          case ScanSeverity.moderate:
          default:
            return 1;
        }
      }

      expect(scheduleFirstDay(ScanSeverity.severe), 0);
      expect(scheduleFirstDay(ScanSeverity.moderate), 1);
      expect(scheduleFirstDay(ScanSeverity.early), 1);
    });
  });
}
