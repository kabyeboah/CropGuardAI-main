import '../../data/ml/crop_disease_classifier.dart';
import '../../domain/models/disease_risk.dart';

/// Heuristic risk-weighted classifier adjuster that incorporates regional outbreak data
/// and weather risk assessments to boost confidence scores of ambiguous ML disease predictions
/// using additive weighting factors and re-normalization.
class RiskWeightedClassifier {
  /// Maps DiseaseRiskType enum to common class label substrings.
  static bool _matchesDiseaseType(String label, DiseaseRiskType type) {
    final normalized = label.toLowerCase().replaceAll('_', ' ');
    switch (type) {
      case DiseaseRiskType.blackPod:
        return normalized.contains('black pod') ||
            normalized.contains('phytophthora');
      case DiseaseRiskType.lateBlight:
        return normalized.contains('late blight') ||
            normalized.contains('phytophthora infestans');
      case DiseaseRiskType.earlyBlight:
        return normalized.contains('early blight') ||
            normalized.contains('alternaria');
      case DiseaseRiskType.leafBlightRust:
        return normalized.contains('rust') ||
            normalized.contains('leaf blight');
      case DiseaseRiskType.riceBlast:
        return normalized.contains('blast') ||
            normalized.contains('magnaporthe');
    }
  }

  /// Adjusts candidate probabilities using nearby outbreak reports and regional disease risks.
  static List<TopCandidate> adjustCandidatesWithRegionalRisk({
    required List<TopCandidate> candidates,
    required List<DiseaseRisk> regionalRisks,
  }) {
    if (candidates.isEmpty || regionalRisks.isEmpty) {
      return candidates;
    }

    final updatedMap = <String, double>{};

    for (final candidate in candidates) {
      double boostedConfidence = candidate.confidence;

      for (final risk in regionalRisks) {
        if (_matchesDiseaseType(candidate.label, risk.type)) {
          if (risk.level == RiskLevel.high) {
            boostedConfidence += 0.15;
          } else if (risk.level == RiskLevel.moderate) {
            boostedConfidence += 0.08;
          }
          if (risk.hasNearbyOutbreak) {
            boostedConfidence += 0.10;
          }
        }
      }

      updatedMap[candidate.label] = boostedConfidence.clamp(0.0, 0.98);
    }

    // Re-normalize probabilities
    final total = updatedMap.values.fold(0.0, (sum, val) => sum + val);
    final List<TopCandidate> adjusted = updatedMap.entries.map((e) {
      final normalizedConfidence = total > 0 ? (e.value / total) : e.value;
      return (label: e.key, confidence: normalizedConfidence);
    }).toList();

    adjusted.sort((a, b) => b.confidence.compareTo(a.confidence));
    return adjusted;
  }
}
