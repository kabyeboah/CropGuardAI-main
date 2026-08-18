import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/risk_weighted_classifier.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/domain/models/disease_risk.dart';

void main() {
  group('RiskWeightedClassifier Unit Tests', () {
    test('boosts confidence when candidate disease matches regional high outbreak risk', () {
      final List<TopCandidate> candidates = [
        (label: 'Cocoa___Black_pod_rot', confidence: 0.40),
        (label: 'Cocoa___Healthy', confidence: 0.35),
        (label: 'Cocoa___Frosty_pod_rot', confidence: 0.25),
      ];

      final List<DiseaseRisk> risks = [
        const DiseaseRisk(
          type: DiseaseRiskType.blackPod,
          level: RiskLevel.high,
          humidity: 88,
          temp: 24,
          hasNearbyOutbreak: true,
        ),
      ];

      final adjusted = RiskWeightedClassifier.adjustCandidatesWithRegionalRisk(
        candidates: candidates,
        regionalRisks: risks,
      );

      expect(adjusted.first.label, equals('Cocoa___Black_pod_rot'));
      expect(adjusted.first.confidence, greaterThan(0.40));
    });

    test('returns original candidates unchanged if no regional risks exist', () {
      final List<TopCandidate> candidates = [
        (label: 'Cassava___Mosaic_disease', confidence: 0.70),
        (label: 'Cassava___Healthy', confidence: 0.30),
      ];

      final adjusted = RiskWeightedClassifier.adjustCandidatesWithRegionalRisk(
        candidates: candidates,
        regionalRisks: [],
      );

      expect(adjusted.length, equals(2));
      expect(adjusted.first.label, equals('Cassava___Mosaic_disease'));
      expect(adjusted.first.confidence, equals(0.70));
    });
  });
}
