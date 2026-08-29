import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';

void main() {
  group('Soft-Voting Ensemble Probability Averaging', () {
    test('averages probabilities correctly across multiple photo predictions using computeSoftVotingCandidates', () {
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

      final averaged = CropDiseaseClassifier.computeSoftVotingCandidates(allPhotos);

      expect(averaged[0].label, equals('Cassava_Mosaic'));
      expect(averaged[0].confidence, closeTo(0.70, 0.001));

      expect(averaged[1].label, equals('Cassava_Green_Mite'));
      expect(averaged[1].confidence, closeTo(0.20, 0.001));

      expect(averaged[2].label, equals('Healthy'));
      expect(averaged[2].confidence, closeTo(0.10, 0.001));
    });

    test('averageResults correctly integrates candidate distributions across angles', () {
      final r1 = ClassificationResult(
        label: 'Cassava_Mosaic',
        confidence: 0.60,
        isHealthy: false,
        diseaseInfo: DiseaseDatabase.getInfo('Cassava_Mosaic'),
        topCandidates: [
          (label: 'Cassava_Mosaic', confidence: 0.60),
          (label: 'Cassava_Green_Mite', confidence: 0.30),
          (label: 'Healthy', confidence: 0.10),
        ],
      );

      final r2 = ClassificationResult(
        label: 'Cassava_Mosaic',
        confidence: 0.80,
        isHealthy: false,
        diseaseInfo: DiseaseDatabase.getInfo('Cassava_Mosaic'),
        topCandidates: [
          (label: 'Cassava_Mosaic', confidence: 0.80),
          (label: 'Cassava_Green_Mite', confidence: 0.10),
          (label: 'Healthy', confidence: 0.10),
        ],
      );

      final r3 = ClassificationResult(
        label: 'Cassava_Mosaic',
        confidence: 0.70,
        isHealthy: false,
        diseaseInfo: DiseaseDatabase.getInfo('Cassava_Mosaic'),
        topCandidates: [
          (label: 'Cassava_Mosaic', confidence: 0.70),
          (label: 'Cassava_Green_Mite', confidence: 0.20),
          (label: 'Healthy', confidence: 0.10),
        ],
      );

      final fused = CropDiseaseClassifier.averageResults([r1, r2, r3]);

      expect(fused.label, equals('Cassava_Mosaic'));
      expect(fused.confidence, closeTo(0.70, 0.001));
      expect(fused.topCandidates, hasLength(3));
      expect(fused.topCandidates[0].label, equals('Cassava_Mosaic'));
      expect(fused.topCandidates[0].confidence, closeTo(0.70, 0.001));
      expect(fused.topCandidates[1].label, equals('Cassava_Green_Mite'));
      expect(fused.topCandidates[1].confidence, closeTo(0.20, 0.001));
      expect(fused.topCandidates[2].label, equals('Healthy'));
      expect(fused.topCandidates[2].confidence, closeTo(0.10, 0.001));
    });
  });
}

