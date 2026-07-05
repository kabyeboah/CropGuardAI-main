/// Likelihood that weather conditions favour a particular crop disease over
/// the coming days. Produced by [AgriWeatherUtils.assessWeeklyRisks] from the
/// forecast — purely rule-based, no ML.
enum RiskLevel { low, moderate, high }

/// Which disease the risk refers to. Kept as an enum (rather than a baked-in
/// English string) so the disease name, crop and reason can all be resolved
/// through localization at the presentation layer.
enum DiseaseRiskType {
  lateBlight,
  earlyBlight,
  blackPod,
  leafBlightRust,
  riceBlast,
}

class DiseaseRisk {
  final DiseaseRiskType type;
  final RiskLevel level;

  /// Averaged forecast values that triggered the risk, surfaced in the
  /// localized reason string (e.g. "Humid (88%) and mild (22°C)…").
  final int humidity;
  final int temp;
  final bool hasNearbyOutbreak;

  const DiseaseRisk({
    required this.type,
    required this.level,
    required this.humidity,
    required this.temp,
    this.hasNearbyOutbreak = false,
  });
}
