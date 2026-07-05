import 'dart:typed_data';
import '../../core/utils/result.dart';
import '../../data/ml/disease_info.dart';

class Classification {
  final String label;
  final double confidence;
  final bool isHealthy;
  final DiseaseInfoEntry diseaseInfo;

  const Classification({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    required this.diseaseInfo,
  });
}

abstract class IClassifierRepository {
  Future<Result<void>> loadModel();
  bool get isModelLoaded;
  Future<Result<Classification?>> classifyFromPath(String imagePath);
  Future<Result<Classification?>> classifyFromBytes(Uint8List rgbaBytes, int width, int height);
  void dispose();
}
