import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

import '../../core/error/failures.dart';
import '../../core/utils/ghana_region.dart';
import '../../core/utils/result.dart';
import '../../domain/models/risk_assessment.dart';
import '../../domain/models/weather_forecast.dart';
import '../../domain/repositories/i_community_repository.dart';
import '../../domain/repositories/i_risk_repository.dart';
import '../../domain/repositories/i_weather_repository.dart';

class RiskRepositoryImpl implements IRiskRepository {
  final ICommunityRepository _communityRepository;
  final IWeatherRepository _weatherRepository;

  RiskRepositoryImpl(
    this._communityRepository,
    this._weatherRepository,
  );

  @override
  Future<Result<RiskAssessment>> getRiskForLocation({
    required double lat,
    required double lon,
    String? cropType,
  }) async {
    try {
      final reportsResult = await _communityRepository.getOutbreakReports();
      if (reportsResult.isError) {
        return Result.error(reportsResult.failure!);
      }

      final rawReports = reportsResult.data ?? [];

      // ─── GUARDRAIL 1: EXCLUDE SEED DATA ─────────────────────────────────────
      // Seed reports (from _kSeedOutbreakReports or demo state) must NEVER be
      // used in calculating a real risk assessment score.
      final nonSeedReports = rawReports.where((r) {
        final isSeedBool = r['isSeed'] == true;
        final sourceSeed = r['source'] == 'seed';
        final idSeed = r['id']?.toString().startsWith('seed_') ?? false;
        return !isSeedBool && !sourceSeed && !idSeed;
      }).toList();

      final region = GhanaRegion.forCoordinates(lat, lon);

      // Filter reports within ~50km OR in the same region, and within last 30 days
      final now = DateTime.now();
      final localReports = nonSeedReports.where((r) {
        // Date check (last 30 days)
        final dt = _parseDate(r);
        if (dt != null && now.difference(dt).inDays > 30) return false;

        // Crop filter if cropType specified
        if (cropType != null && cropType.isNotEmpty) {
          final rCrop = (r['cropType'] as String?) ?? _cropOfDisease((r['disease'] ?? r['diseaseName'] ?? '').toString());
          if (rCrop.toLowerCase() != cropType.toLowerCase()) return false;
        }

        // Region / Geo check
        final rRegion = (r['region'] as String?) ?? (r['location'] as String?);
        if (rRegion != null && rRegion.toLowerCase() == region.toLowerCase()) {
          return true;
        }

        final rLat = (r['latitude'] as num?)?.toDouble();
        final rLng = (r['longitude'] as num?)?.toDouble();
        if (rLat != null && rLng != null) {
          final distMeters = Geolocator.distanceBetween(lat, lon, rLat, rLng);
          if (distMeters <= 50000) return true; // 50 km radius
        }

        return false;
      }).toList();

      // Fetch Weather Forecast (used for both low-density fallback and full crowd-density multiplier)
      WeatherForecast? forecast;
      try {
        forecast = await _weatherRepository.getWeatherForecast(latitude: lat, longitude: lon);
      } catch (_) {
        // Weather fetch failed; proceed with density alone
      }

      // Compute trust-weighted density score
      // Weight per report = 1 + verifiedBy.length - refutedBy.length (min 1)
      double totalTrustWeight = 0;
      for (final r in localReports) {
        final verifiedBy = (r['verifiedBy'] as List?) ?? [];
        final refutedBy = (r['refutedBy'] as List?) ?? [];
        final w = (1 + verifiedBy.length - refutedBy.length).clamp(1, 100).toDouble();
        totalTrustWeight += w;
      }

      // ─── HYBRID WEATHER-FIRST FALLBACK MODEL FOR LOW REPORT DENSITY (< 3) ───
      if (localReports.length < 3) {
        // If weather forecast data is unavailable AND 0 community reports exist, return insufficient data
        if (forecast == null || forecast.daily.isEmpty) {
          return Result.success(RiskAssessment(
            region: region,
            latitude: lat,
            longitude: lon,
            cropType: cropType,
            riskLevel: RiskLevel.none,
            confidence: RiskConfidence.insufficientData,
            contributingFactors: [
              'Insufficient local outbreak report data (fewer than 3 reports in region in last 30 days) and weather forecast unavailable to synthesize risk score',
            ],
            computedAt: now,
          ));
        }

        final factors = <String>[];
        final window = forecast.daily.take(3).toList();
        final n = window.length;

        final avgMaxTemp = window.map((d) => d.maxTemp).reduce((a, b) => a + b) / n;
        final avgHumidity = window.map((d) => d.humidity).reduce((a, b) => a + b) / n;
        final avgRain = window.map((d) => d.precipitationProbability).reduce((a, b) => a + b) / n;
        final hum = avgHumidity > 0 ? avgHumidity : avgRain;

        double weatherRiskScore = 0.1; // Baseline minimal risk score

        // Fungal pathogens: High humidity (>75%) & mild/warm temp (20-30°C)
        if (hum >= 75 && avgMaxTemp >= 20 && avgMaxTemp <= 30) {
          weatherRiskScore += 0.35;
          factors.add('Sustained high humidity (${hum.round()}%) and moderate temp (${avgMaxTemp.round()}°C) favor fungal pathogen spread');
        }

        // Bacterial pathogens: High temp (>25°C) & high humidity or rain
        if (hum >= 70 && avgMaxTemp >= 26) {
          weatherRiskScore += 0.25;
          factors.add('Warm and humid weather conditions favor bacterial leaf spot/blight development');
        }

        // Viral/vector pathogens: Warm temperatures favoring vector activity
        if (avgMaxTemp >= 28) {
          weatherRiskScore += 0.15;
          factors.add('Elevated temperatures (${avgMaxTemp.round()}°C) favor vector activity (whiteflies & aphids)');
        }

        if (localReports.isNotEmpty) {
          weatherRiskScore += localReports.length * 0.10;
          factors.add('${localReports.length} local outbreak report(s) recorded in region in last 30 days');
        }

        if (cropType != null && cropType.isNotEmpty) {
          factors.add('Forecast evaluated specifically for $cropType vulnerability under current microclimate');
        }

        factors.add('Preliminary forecast synthesized primarily from microclimate weather data due to sparse community report density (${localReports.length} reports in area)');

        final RiskLevel level;
        if (weatherRiskScore >= 0.65) {
          level = RiskLevel.high;
        } else if (weatherRiskScore >= 0.35) {
          level = RiskLevel.moderate;
        } else if (weatherRiskScore >= 0.20) {
          level = RiskLevel.low;
        } else {
          level = RiskLevel.none;
        }

        return Result.success(RiskAssessment(
          region: region,
          latitude: lat,
          longitude: lon,
          cropType: cropType,
          riskLevel: level,
          confidence: RiskConfidence.low,
          contributingFactors: factors,
          computedAt: now,
        ));
      }

      final factors = <String>[];
      factors.add(
        '${localReports.length} verified outbreak reports (${totalTrustWeight.round()} trust points) within region in last 30 days',
      );

      double weatherMultiplier = 1.0;
      if (forecast != null && forecast.daily.isNotEmpty) {
        final window = forecast.daily.take(3).toList();
        final n = window.length;

        final avgMaxTemp = window.map((d) => d.maxTemp).reduce((a, b) => a + b) / n;
        final avgHumidity = window.map((d) => d.humidity).reduce((a, b) => a + b) / n;
        final avgRain = window.map((d) => d.precipitationProbability).reduce((a, b) => a + b) / n;
        final hum = avgHumidity > 0 ? avgHumidity : avgRain;

        // Fungal pathogens: High humidity (>75%) & mild/warm temp (20-30°C)
        if (hum >= 75 && avgMaxTemp >= 20 && avgMaxTemp <= 30) {
          weatherMultiplier += 0.3;
          factors.add('Sustained high humidity (${hum.round()}%) and moderate temp (${avgMaxTemp.round()}°C) favor fungal pathogen spread');
        }

        // Bacterial pathogens: High temp (>25°C) & high humidity or rain
        if (hum >= 70 && avgMaxTemp >= 26) {
          weatherMultiplier += 0.2;
          factors.add('Warm and humid weather conditions favor bacterial leaf spot/blight development');
        }

        // Viral/vector pathogens: Warm temperatures favoring vector (whitefly/aphids) activity
        if (avgMaxTemp >= 28) {
          weatherMultiplier += 0.15;
          factors.add('Elevated temperatures (${avgMaxTemp.round()}°C) favor vector activity (whiteflies & aphids)');
        }
      }

      if (cropType != null && cropType.isNotEmpty) {
        factors.add('Active outbreaks confirmed specifically for $cropType in the area');
      }

      // Scoring formula: density component * weather multiplier
      // Base density: 3 reports = 0.4, 6+ reports = 0.8+
      final baseDensityScore = math.min(totalTrustWeight / 6.0, 1.0);
      final finalScore = baseDensityScore * weatherMultiplier;

      final RiskLevel level;
      if (finalScore >= 0.8) {
        level = RiskLevel.high;
      } else if (finalScore >= 0.4) {
        level = RiskLevel.moderate;
      } else {
        level = RiskLevel.low;
      }

      final RiskConfidence confidence;
      if (localReports.length >= 7) {
        confidence = RiskConfidence.high;
      } else if (localReports.length >= 4) {
        confidence = RiskConfidence.medium;
      } else {
        confidence = RiskConfidence.low;
      }

      return Result.success(RiskAssessment(
        region: region,
        latitude: lat,
        longitude: lon,
        cropType: cropType,
        riskLevel: level,
        confidence: confidence,
        contributingFactors: factors,
        computedAt: now,
      ));
    } catch (e) {
      return Result.error(ServerFailure('Failed to assess risk: $e'));
    }
  }

  DateTime? _parseDate(Map<String, dynamic> r) {
    final ts = r['timestamp'] ?? r['date'] ?? r['reportedAt'];
    if (ts is DateTime) return ts;
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) {
      try {
        return DateTime.parse(ts);
      } catch (_) {}
    }
    return null;
  }

  String _cropOfDisease(String disease) {
    final d = disease.toLowerCase();
    final crops = [
      'Cassava', 'Cocoa', 'Maize', 'Tomato', 'Rice', 'Banana',
      'Yam', 'Groundnut', 'Cowpea', 'Oil Palm', 'Sorghum', 'Millet',
    ];
    for (final c in crops) {
      if (d.startsWith(c.toLowerCase())) return c;
    }
    return 'Other';
  }
}
