import 'dart:typed_data';
import '../../core/error/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/i_classifier_repository.dart';
import '../ml/crop_disease_classifier.dart';
import '../ml/disease_info.dart';
import '../ml/ood_gate.dart';
import '../remote/gemini_cloud_ai_service.dart';

import '../../core/utils/classifier_health_service.dart';

class ClassifierRepositoryImpl implements IClassifierRepository {
  final CropDiseaseClassifier _classifier;
  final OODGate _oodGate;
  final ClassifierHealthService? _healthService;
  final GeminiCloudAiService? _cloudAiService;

  ClassifierRepositoryImpl(
    this._classifier, [
    OODGate? oodGate,
    ClassifierHealthService? healthService,
    GeminiCloudAiService? cloudAiService,
  ])  : _oodGate = oodGate ?? AlwaysAcceptOODGate(),
        _healthService = healthService,
        _cloudAiService = cloudAiService;

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
        _healthService?.updateHealth(isHealthy: false);
        if (_cloudAiService != null) {
          try {
            final cloudResult =
                await _cloudAiService.analyzeCropImage(imagePath: imagePath);
            final info = DiseaseDatabase.getInfo(cloudResult.label);
            return Result.success(Classification(
              label: cloudResult.label,
              confidence: cloudResult.confidence,
              isHealthy: cloudResult.isHealthy,
              diseaseInfo: info,
              isDegraded: false,
              topCandidates: [
                (label: cloudResult.label, confidence: cloudResult.confidence)
              ],
              modelVersion: 'Gemini Cloud AI',
            ));
          } catch (_) {
            // Cloud fallback also failed, return standard engine failure
          }
        }
        return Result.error(const ModelLoadFailure(
            'ML engine unavailable on this platform or device'));
      }
      _healthService?.updateHealth(
        isHealthy: true,
        modelVersion: result.modelVersion,
      );
      return Result.success(_mapClassification(result));
    } catch (e) {
      if ((e is ModelLoadException || e is ModelInferenceException) &&
          _cloudAiService != null) {
        try {
          final cloudResult =
              await _cloudAiService.analyzeCropImage(imagePath: imagePath);
          final info = DiseaseDatabase.getInfo(cloudResult.label);
          return Result.success(Classification(
            label: cloudResult.label,
            confidence: cloudResult.confidence,
            isHealthy: cloudResult.isHealthy,
            diseaseInfo: info,
            isDegraded: false,
            topCandidates: [
              (label: cloudResult.label, confidence: cloudResult.confidence)
            ],
            modelVersion: 'Gemini Cloud AI',
          ));
        } catch (_) {
          // Fallback also failed; proceed to map original exception
        }
      }
      _healthService?.updateHealth(isHealthy: false);
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
        _healthService?.updateHealth(isHealthy: false);
        return Result.error(const ModelLoadFailure(
            'ML engine unavailable on this platform or device'));
      }
      _healthService?.updateHealth(
        isHealthy: true,
        modelVersion: result.modelVersion,
      );
      return Result.success(_mapClassification(result));
    } catch (e) {
      _healthService?.updateHealth(isHealthy: false);
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
