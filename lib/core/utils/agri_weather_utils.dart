import '../../domain/models/disease_risk.dart';
import '../../domain/models/weather_forecast.dart';

class AgriWeatherUtils {
  /// Conditions favor fungal disease (like late blight):
  /// Humidity > 80% and Temperature between 20-30°C
  static bool isFungalRisk(DailyForecast forecast) {
    return forecast.humidity > 80 &&
           forecast.maxTemp >= 20 &&
           forecast.maxTemp <= 30;
  }

  /// Produces a short, prioritised disease-risk outlook for the next few days
  /// from the daily forecast. Rule-based agronomic heuristics keyed to Ghana's
  /// main crops — humidity, temperature and rain-probability windows that are
  /// known to favour each disease. Returns at most [maxRisks] entries, highest
  /// severity first, and only moderate/high risks (low risk is not surfaced).
  static List<DiseaseRisk> assessWeeklyRisks(
    List<DailyForecast> daily, {
    List<Map<String, dynamic>> outbreaks = const [],
    String region = '',
    int maxRisks = 3,
  }) {
    if (daily.isEmpty) return const [];

    // Parse active, verified regional outbreaks reported in the last 14 days
    final activeDiseases = outbreaks.where((o) {
      final oReg = (o['region'] as String?)?.toLowerCase();
      if (oReg == null || oReg != region.toLowerCase()) return false;
      
      final verifiedBy = (o['verifiedBy'] as List?) ?? [];
      final refutedBy = (o['refutedBy'] as List?) ?? [];
      if (verifiedBy.length < 3 || refutedBy.length > verifiedBy.length) return false;

      final ts = o['timestamp'] ?? o['date'];
      DateTime? dt;
      if (ts is DateTime) {
        dt = ts;
      } else if (ts is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(ts);
      } else if (ts != null) {
        try {
          dt = ts.toDate() as DateTime?;
        } catch (_) {}
      }
      
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inDays <= 14) return true;
      }
      return false;
    }).map((o) => (o['disease'] as String? ?? o['diseaseName'] as String? ?? '').toLowerCase()).toSet();

    bool hasOutbreak(DiseaseRiskType type) {
      final keyword = switch (type) {
        DiseaseRiskType.lateBlight => 'late blight',
        DiseaseRiskType.earlyBlight => 'early blight',
        DiseaseRiskType.blackPod => 'black pod',
        DiseaseRiskType.leafBlightRust => 'rust',
        DiseaseRiskType.riceBlast => 'blast',
      };
      
      for (final d in activeDiseases) {
        if (d.contains(keyword)) return true;
        if (type == DiseaseRiskType.leafBlightRust && d.contains('blight') && d.contains('maize')) return true;
      }
      return false;
    }

    // Look at the next up-to-3 days — long enough to catch a sustained humid
    // spell, short enough that the forecast is still reliable.
    final window = daily.take(3).toList();
    final n = window.length;

    double avg(double Function(DailyForecast) f) =>
        window.map(f).reduce((a, b) => a + b) / n;

    final avgMax = avg((d) => d.maxTemp);
    final avgRain = avg((d) => d.precipitationProbability);
    // Humidity can be absent (0) on some responses — fall back to using rain
    // probability as a wetness proxy so the rules still fire sensibly.
    var avgHum = avg((d) => d.humidity);
    if (avgHum <= 0) avgHum = avgRain;

    final wetDays =
        window.where((d) => d.precipitationProbability >= 50).length;

    final risks = <DiseaseRisk>[];
    final hum = avgHum.round();
    final temp = avgMax.round();

    void add(DiseaseRiskType type, RiskLevel level) {
      final confirmed = hasOutbreak(type);
      final finalLevel = confirmed ? RiskLevel.high : level;
      risks.add(DiseaseRisk(
        type: type,
        level: finalLevel,
        humidity: hum,
        temp: temp,
        hasNearbyOutbreak: confirmed,
      ));
    }

    // Late blight (tomato/potato): cool-to-mild + very humid for days.
    if (avgHum >= 80 && avgMax >= 15 && avgMax <= 25) {
      add(DiseaseRiskType.lateBlight,
          (avgHum >= 88 && wetDays >= 2) ? RiskLevel.high : RiskLevel.moderate);
    }

    // Early blight (tomato): warm + persistent moisture.
    if (avgHum >= 70 && avgMax >= 24 && avgMax <= 30) {
      add(DiseaseRiskType.earlyBlight,
          avgHum >= 80 ? RiskLevel.high : RiskLevel.moderate);
    }

    // Cocoa black pod: prolonged wet, very high humidity.
    if (avgHum >= 85 && wetDays >= 2) {
      add(DiseaseRiskType.blackPod,
          wetDays >= 3 ? RiskLevel.high : RiskLevel.moderate);
    }

    // Maize leaf blight / rust: warm + humid.
    if (avgHum >= 75 && avgMax >= 20 && avgMax <= 30) {
      add(DiseaseRiskType.leafBlightRust,
          avgHum >= 85 ? RiskLevel.high : RiskLevel.moderate);
    }

    // Rice blast: warm days with frequent rain / high humidity.
    if (avgHum >= 80 && wetDays >= 2 && avgMax >= 22 && avgMax <= 30) {
      add(DiseaseRiskType.riceBlast,
          avgHum >= 88 ? RiskLevel.high : RiskLevel.moderate);
    }

    // Inject nearby confirmed outbreaks that weren't triggered by weather rules
    for (final type in DiseaseRiskType.values) {
      final alreadyAdded = risks.any((r) => r.type == type);
      if (!alreadyAdded && hasOutbreak(type)) {
        risks.add(DiseaseRisk(
          type: type,
          level: RiskLevel.moderate,
          humidity: hum,
          temp: temp,
          hasNearbyOutbreak: true,
        ));
      }
    }

    risks.sort((a, b) => b.level.index.compareTo(a.level.index));
    return risks.take(maxRisks).toList();
  }

  /// Returns advice on whether it's safe to spray.
  /// Ideally, no rain for at least 6 hours after spraying.
  /// For simplicity with daily forecast, we check precipitation probability.
  static String getSprayAdvisory(DailyForecast forecast) {
    if (forecast.precipitationProbability > 50) {
      return "Rain likely (${forecast.precipitationProbability.toInt()}%). Avoid spraying today as it may wash off.";
    } else if (forecast.precipitationProbability > 20) {
      return "Low rain risk (${forecast.precipitationProbability.toInt()}%). Spray with caution in the early morning.";
    } else {
      return "Excellent spray window! No rain forecast (0-20%).";
    }
  }

  /// Ghana Planting Calendar Logic
  /// Regions: 'North' (1 rainy season: May-Oct), 'South' (2 rainy seasons: Mar-Jun, Sep-Nov)
  static Map<String, String> getPlantingAdvice(String region) {
    final now = DateTime.now();
    final month = now.month;

    if (region == 'North') {
      if (month >= 5 && month <= 6) return {"status": "Planting Season", "action": "Ideal for Maize, Millet, and Yam."};
      if (month >= 7 && month <= 9) return {"status": "Growing Season", "action": "Monitor for Fall Armyworm."};
      if (month >= 10 && month <= 11) return {"status": "Harvesting", "action": "Dry grains properly to avoid Aflatoxins."};
      return {"status": "Dry Season", "action": "Prepare land for May planting."};
    } else {
      // South
      if (month >= 3 && month <= 4) return {"status": "Major Season Planting", "action": "Plant Maize and Cassava now."};
      if (month >= 5 && month <= 6) return {"status": "Major Growing Season", "action": "High humidity risk for Fungal diseases."};
      if (month >= 9 && month <= 10) return {"status": "Minor Season Planting", "action": "Short-duration crops recommended."};
      if (month == 11 || month == 12) return {"status": "Minor Harvesting", "action": "Prepare for Harmattan dry spells."};
      return {"status": "Off-season", "action": "Ideal for irrigation farming / vegetables."};
    }
  }
}
