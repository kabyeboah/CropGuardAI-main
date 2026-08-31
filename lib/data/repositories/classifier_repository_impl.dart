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

  Failure _mapException(Object e) {
    if (e is ModelLoadException) {
      return ModelLoadFailure(e.message);
    }
    if (e is ModelContractException) {
      return ModelContractFailure(e.message);
    }
    if (e is ModelInputException) {
      return ModelInputFailure(e.message);
    }
    if (e is ModelInferenceException) {
      return ModelInferenceFailure(e.message);
    }
    if (e is LabelContractException) {
      return LabelContractFailure(e.message);
    }
    if (e is MLException) {
      return MLFailure(e.message, code: e.code);
    }
    return MLFailure(e.toString());
  }

  @override
  Future<Result<void>> loadModel() async {
    try {
      await _classifier.loadModel();
      return Result.success(null);
    } catch (e) {
      return Result.error(_mapException(e));
    }
  }

  @override
  bool get isModelLoaded => _classifier.isLoaded;

  @override
  Future<Result<Classification?>> classifyFromPath(String imagePath) async {
    try {
      final isPlant = await _oodGate.isPlantImage(imagePath);
      if (!isPlant) {
        return Result.error(const OODFailure());
      }

      final result = await _classifier.classifyFromPath(imagePath);
      if (result == null) {
        return Result.error(const ModelInferenceFailure(
            'Classification failed to return a result'));
      }
      if (result.qualityResult != null && !result.qualityResult!.isAcceptable) {
        return Result.error(QualityFailure(
            result.qualityResult!.issue, 'Image quality check failed'));
      }
      if (result.engineUnavailable) {
        return Result.error(const ModelLoadFailure(
            'ML engine unavailable on this platform or device'));
      }
      return Result.success(_mapClassification(result));
    } catch (e) {
      return Result.error(_mapException(e));
    }
  }

  @override
  Future<Result<Classification?>> classifyFromBytes(
      Uint8List rgbaBytes, int width, int height) async {
    try {
      final isPlant = await _oodGate.isPlantBytes(rgbaBytes, width, height);
      if (!isPlant) {
        return Result.error(const OODFailure());
      }

      final result =
          await _classifier.classifyFromBytes(rgbaBytes, width, height);
      if (result == null) {
        return Result.error(const ModelInferenceFailure(
            'Classification failed to return a result'));
      }
      if (result.qualityResult != null && !result.qualityResult!.isAcceptable) {
        return Result.error(QualityFailure(
            result.qualityResult!.issue, 'Image quality check failed'));
      }
      if (result.engineUnavailable) {
        return Result.error(const ModelLoadFailure(
            'ML engine unavailable on this platform or device'));
      }
      return Result.success(_mapClassification(result));
    } catch (e) {
      return Result.error(_mapException(e));
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
      modelVersion: result.modelVersion,
    );
  }
}
