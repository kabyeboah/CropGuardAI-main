import 'dart:async';

import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/streak_manager.dart';
import '../../../data/ml/crop_disease_classifier.dart';
import '../../../data/ml/disease_info.dart';
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
    final classificationResult =
        await _classifierRepository.classifyFromPath(imagePath);

    if (classificationResult.isError) {
      return Result.error(classificationResult.failure!);
    }

    final classification = classificationResult.data;
    if (classification == null) {
      return Result.error(
          const MLFailure('Classification failed to return a result'));
    }

    return saveResolvedScan(
      imagePath: imagePath,
      userId: userId,
      diseaseLabel: classification.label,
      confidence: classification.confidence,
      topCandidates: classification.topCandidates,
      isDegraded: classification.isDegraded,
      modelVersion: classification.modelVersion,
    );
  }

  /// Persists a resolved scan result (such as from multi-angle soft-voting fusion
  /// or user-confirmed candidate) directly to SQLite, streak manager, and Firestore.
  Future<Result<DetectionResult>> saveResolvedScan({
    required String imagePath,
    required String userId,
    required String diseaseLabel,
    required double confidence,
    required List<TopCandidate> topCandidates,
    bool isDegraded = false,
    String? modelVersion,
  }) async {
    final diseaseInfo = DiseaseDatabase.getInfo(diseaseLabel);
    final severity = diseaseInfo.severity;

    final detection = DetectionResult(
      userId: userId,
      imagePath: imagePath,
      diseaseLabel: diseaseLabel,
      displayName: diseaseInfo.displayName,
      confidence: confidence,
      severity: severity,
      isHealthy: diseaseInfo.isHealthy,
      cropType: diseaseInfo.cropType,
      cause: diseaseInfo.cause,
      treatments: diseaseInfo.treatments,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDegraded: isDegraded,
      topCandidates: topCandidates,
      modelVersion: modelVersion ?? CropDiseaseClassifier.modelVersion,
    );

    final saveResult = await _detectionRepository.saveDetection(detection);

    if (saveResult.isError) {
      return Result.error(saveResult.failure!);
    }

    unawaited(_streakManager.recordScan());

    final savedDetection = detection.copyWith(id: saveResult.data);
    if (_communityRepository != null) {
      unawaited(_communityRepository.upsertScan(
        savedDetection.id.toString(),
        savedDetection.toMap(),
      ));
    }

    return Result.success(savedDetection);
  }
}
