import 'dart:typed_data';
import '../../core/error/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/i_classifier_repository.dart';
import '../ml/crop_disease_classifier.dart';
import '../ml/ood_gate.dart';

class ClassifierRepositoryImpl implements IClassifierRepository {
  final CropDiseaseClassifier _classifier;
  final OODGate _oodGate;

  ClassifierRepositoryImpl(this._classifier, [OODGate? oodGate])
      : _oodGate = oodGate ?? AlwaysAcceptOODGate();

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
      final isPlant = await _oodGate.isPlantImage(imagePath);
      if (!isPlant) {
        return Result.error(OODFailure());
      }

      final result = await _classifier.classifyFromPath(imagePath);
      if (result == null) {
        return Result.error(MLFailure('Classification failed to return a result'));
      }
      if (result.engineUnavailable) {
        return Result.error(MLFailure('ML engine unavailable on this platform or device'));
      }
      if (result.qualityResult != null && !result.qualityResult!.isAcceptable) {
        return Result.error(QualityFailure(result.qualityResult!.issue, 'Image quality check failed'));
      }
      return Result.success(_mapClassification(result));
    } catch (e) {
      return Result.error(MLFailure(e.toString()));
    }
  }

  @override
  Future<Result<Classification?>> classifyFromBytes(Uint8List rgbaBytes, int width, int height) async {
    try {
      final isPlant = await _oodGate.isPlantBytes(rgbaBytes, width, height);
      if (!isPlant) {
        return Result.error(OODFailure());
      }

      final result = await _classifier.classifyFromBytes(rgbaBytes, width, height);
      if (result == null) {
        return Result.error(MLFailure('Classification failed to return a result'));
      }
      if (result.engineUnavailable) {
        return Result.error(MLFailure('ML engine unavailable on this platform or device'));
      }
      if (result.qualityResult != null && !result.qualityResult!.isAcceptable) {
        return Result.error(QualityFailure(result.qualityResult!.issue, 'Image quality check failed'));
      }
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
      isDegraded: result.isDegraded,
      topCandidates: result.topCandidates,
    );
  }
}
