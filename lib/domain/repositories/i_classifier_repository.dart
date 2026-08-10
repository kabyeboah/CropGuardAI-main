import 'dart:typed_data';
import '../../core/utils/result.dart';
import '../../data/ml/crop_disease_classifier.dart';
import '../../data/ml/disease_info.dart';

class Classification {
  final String label;
  final double confidence;
  final bool isHealthy;
  final DiseaseInfoEntry diseaseInfo;
  // True when this result came from the fallback heuristic (engine failed to
  // load, or the real model's confidence was below the accept threshold)
  // rather than a genuine model prediction. Must be threaded through to
  // anything that persists or displays this result — see
  // ScanCropUseCase and the history screen.
  final bool isDegraded;
  final List<TopCandidate> topCandidates;

  const Classification({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    required this.diseaseInfo,
    this.isDegraded = false,
    this.topCandidates = const [],
  });
}

abstract class IClassifierRepository {
  Future<Result<void>> loadModel();
  bool get isModelLoaded;
  Future<Result<Classification?>> classifyFromPath(String imagePath);
  Future<Result<Classification?>> classifyFromBytes(Uint8List rgbaBytes, int width, int height);
  void dispose();
}
