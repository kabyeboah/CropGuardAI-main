import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';

void main() {
  group('Soft-Voting Ensemble Probability Averaging', () {
    test('averages probabilities correctly across multiple photo predictions', () {
      final photo1Candidates = <TopCandidate>[
        (label: 'Cassava_Mosaic', confidence: 0.60),
        (label: 'Cassava_Green_Mite', confidence: 0.30),
        (label: 'Healthy', confidence: 0.10),
      ];

      final photo2Candidates = <TopCandidate>[
        (label: 'Cassava_Mosaic', confidence: 0.80),
        (label: 'Cassava_Green_Mite', confidence: 0.10),
        (label: 'Healthy', confidence: 0.10),
      ];

      final photo3Candidates = <TopCandidate>[
        (label: 'Cassava_Mosaic', confidence: 0.70),
        (label: 'Cassava_Green_Mite', confidence: 0.20),
        (label: 'Healthy', confidence: 0.10),
      ];

      final allPhotos = [photo1Candidates, photo2Candidates, photo3Candidates];

      final Map<String, double> labelSumMap = {};
      for (final photoCandidates in allPhotos) {
        for (final c in photoCandidates) {
          labelSumMap[c.label] = (labelSumMap[c.label] ?? 0.0) + c.confidence;
        }
      }

      final int n = allPhotos.length;
      final List<TopCandidate> averaged = labelSumMap.entries.map((e) {
        return (label: e.key, confidence: e.value / n);
      }).toList();
      averaged.sort((a, b) => b.confidence.compareTo(a.confidence));

      expect(averaged[0].label, equals('Cassava_Mosaic'));
      expect(averaged[0].confidence, closeTo(0.70, 0.001));

      expect(averaged[1].label, equals('Cassava_Green_Mite'));
      expect(averaged[1].confidence, closeTo(0.20, 0.001));

      expect(averaged[2].label, equals('Healthy'));
      expect(averaged[2].confidence, closeTo(0.10, 0.001));
    });
  });
}
