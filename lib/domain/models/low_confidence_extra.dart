import '../../data/ml/crop_disease_classifier.dart';
import 'disease_risk.dart';

/// Typed payload passed via GoRouter [extra] to the `/low_confidence` route.
///
/// Using a typed object (rather than query-params) lets us carry the
/// [topCandidates] list — a query param cannot hold a structured list.
class LowConfidenceExtra {
  final double confidence;
  final String imagePath;
  final List<TopCandidate> topCandidates;
  final List<DiseaseRisk>? regionalRisks;

  const LowConfidenceExtra({
    required this.confidence,
    required this.imagePath,
    this.topCandidates = const [],
    this.regionalRisks,
  });
}
