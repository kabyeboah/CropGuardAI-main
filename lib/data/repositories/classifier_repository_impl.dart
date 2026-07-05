import 'dart:typed_data';
import '../../core/error/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/i_classifier_repository.dart';
import '../ml/crop_disease_classifier.dart';

class ClassifierRepositoryImpl implements IClassifierRepository {
  final CropDiseaseClassifier _classifier;

  ClassifierRepositoryImpl(this._classifier);

  @override
  Future<Result<void>> loadModel() async {
    try {
      await _classifier.loadModel();
      return Result.success(null);
    } catch (e) {
      return Result.error(MLFailure(e.toString()));
    }
  }

  @override
  bool get isModelLoaded => _classifier.isLoaded;

  @override
  Future<Result<Classification?>> classifyFromPath(String imagePath) async {
    try {
      final result = await _classifier.classifyFromPath(imagePath);
      return Result.success(_mapClassification(result));
    } catch (e) {
      return Result.error(MLFailure(e.toString()));
    }
  }

  @override
  Future<Result<Classification?>> classifyFromBytes(Uint8List rgbaBytes, int width, int height) async {
    try {
      final result = await _classifier.classifyFromBytes(rgbaBytes, width, height);
      return Result.success(_mapClassification(result));
    } catch (e) {
      return Result.error(MLFailure(e.toString()));
    }
  }

  @override
  void dispose() {
    _classifier.close();
  }

  Classification? _mapClassification(ClassificationResult? result) {
    if (result == null) return null;
    return Classification(
      label: result.label,
      confidence: result.confidence,
      isHealthy: result.isHealthy,
      diseaseInfo: result.diseaseInfo,
    );
  }
}
