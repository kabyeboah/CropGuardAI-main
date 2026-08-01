import 'dart:async';

import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/streak_manager.dart';
import '../../models/detection_result.dart';
import '../../repositories/i_classifier_repository.dart';
import '../../repositories/i_community_repository.dart';
import '../../repositories/i_detection_repository.dart';

class ScanCropUseCase {
  final IClassifierRepository _classifierRepository;
  final IDetectionRepository _detectionRepository;
  final StreakManager _streakManager;
  final ICommunityRepository? _communityRepository;

  ScanCropUseCase(
    this._classifierRepository,
    this._detectionRepository,
    this._streakManager, [
    this._communityRepository,
  ]);

  Future<Result<DetectionResult>> call(String imagePath, String userId) async {
    final classificationResult = await _classifierRepository.classifyFromPath(imagePath);

    if (classificationResult.isError) {
      return Result.error(classificationResult.failure!);
    }

    final classification = classificationResult.data;
    if (classification == null) {
      return Result.error(MLFailure('Classification failed to return a result'));
    }

    // Severity is sourced from the DiseaseDatabase — each disease has a
    // pre-set agronomic severity (early | moderate | severe | healthy).
    // Model confidence is intentionally NOT used as a severity proxy:
    // a high-confidence prediction does not mean the disease is at a severe
    // stage; it only means the model is sure about the diagnosis.
    // Confidence is still used upstream (CropDiseaseClassifier) to trigger
    // the low-confidence warning when it falls below 0.60.
    final severity = classification.diseaseInfo.severity;

    final detection = DetectionResult(
      userId: userId,
      imagePath: imagePath,
      diseaseLabel: classification.label,
      displayName: classification.diseaseInfo.displayName,
      confidence: classification.confidence,
      severity: severity,
      isHealthy: classification.isHealthy,
      cropType: classification.diseaseInfo.cropType,
      cause: classification.diseaseInfo.cause,
      treatments: classification.diseaseInfo.treatments,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDegraded: classification.isDegraded,
    );

    final saveResult = await _detectionRepository.saveDetection(detection);
    
    if (saveResult.isError) {
      return Result.error(saveResult.failure!);
    }

    unawaited(_streakManager.recordScan());

    final savedDetection = detection.copyWith(id: saveResult.data);
    if (_communityRepository != null) {
      unawaited(_communityRepository.uploadScan(savedDetection.toMap()));
    }

    return Result.success(savedDetection);
  }
}
