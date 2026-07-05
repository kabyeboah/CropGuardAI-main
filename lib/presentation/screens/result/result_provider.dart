import 'package:flutter/material.dart';
import '../../../core/utils/agri_weather_utils.dart';
import '../../../core/utils/location_helper.dart';
import '../../../domain/models/detection_result.dart';
import '../../../domain/repositories/i_community_repository.dart';
import '../../../domain/repositories/i_detection_repository.dart';
import '../../../domain/usecases/weather/get_weather_usecase.dart';
import '../../l10n/ui_message.dart';

/// Equivalent of ResultViewModel.kt
class ResultProvider extends ChangeNotifier {
  final IDetectionRepository _detectionRepo;
  final ICommunityRepository _communityRepo;
  final GetWeatherUseCase _getWeatherUseCase;

  ResultProvider(this._detectionRepo, this._communityRepo, this._getWeatherUseCase);

  // This provider is route-scoped (created/disposed on each /result visit), so
  // async work can complete after the user navigates away. Guard all state
  // notifications so we never call notifyListeners() on a disposed object.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  DetectionResult? result;
  String sprayAdvisory = '';
  bool sprayAdvisoryUnavailable = false;
  bool isWeatherLoading = false;
  bool isLoading = false;
  UiMessage? errorCode;
  bool feedbackSent = false;
  bool cropNotFoundSent = false;
  bool expertRequestSent = false;
  bool isRequestingExpert = false;

  Future<void> load(int id) async {
    isLoading = true;
    errorCode = null;
    _safeNotify();

    final res = await _detectionRepo.getDetection(id);
    res.fold(
      (detection) {
        result = detection;
        if (result == null) {
          errorCode = UiMessage.resultNotFound;
        } else if (!result!.isHealthy) {
          _fetchSprayAdvisory();
        }
      },
      (failure) {
        errorCode = UiMessage.couldNotLoadResult;
      },
    );

    isLoading = false;
    _safeNotify();
  }

  Future<void> _fetchSprayAdvisory() async {
    isWeatherLoading = true;
    _safeNotify();
    try {
      final loc = await LocationHelper.currentOrFallback();
      final weather = await _getWeatherUseCase.execute(
          latitude: loc.latitude, longitude: loc.longitude);
      if (weather.daily.isNotEmpty) {
        sprayAdvisory = AgriWeatherUtils.getSprayAdvisory(weather.daily.first);
        sprayAdvisoryUnavailable = false;
      }
    } catch (e) {
      sprayAdvisory = '';
      sprayAdvisoryUnavailable = true;
    } finally {
      isWeatherLoading = false;
      _safeNotify();
    }
  }

  Future<void> submitFeedback({
    required String userId,
    required String correctedLabel,
  }) async {
    if (result == null) return;
    final res = await _communityRepo.submitFeedback(
      userId: userId,
      detectionId: result!.id,
      originalLabel: result!.diseaseLabel,
      correctedLabel: correctedLabel,
    );
    res.fold(
      (_) {
        feedbackSent = true;
        _safeNotify();
      },
      (_) {
        errorCode = UiMessage.sendFeedbackFailed;
        _safeNotify();
      },
    );
  }

  Future<void> submitCropNotFound({
    required String userId,
    required String suggestedCrop,
    required String observedSymptoms,
  }) async {
    if (result == null) return;
    final res = await _communityRepo.submitCropNotFound(
      userId: userId,
      suggestedCrop: suggestedCrop,
      observedSymptoms: observedSymptoms,
      imagePath: result!.imagePath,
    );
    res.fold(
      (_) {
        cropNotFoundSent = true;
        _safeNotify();
      },
      (_) {
        errorCode = UiMessage.submitReportFailed;
        _safeNotify();
      },
    );
  }

  Future<void> requestExpertHelp({
    required String userId,
    required String message,
  }) async {
    if (result == null) return;
    isRequestingExpert = true;
    _safeNotify();
    final res = await _communityRepo.requestExpertHelp(
      userId: userId,
      detectionId: result!.id.toString(),
      message: message,
      diseaseName: result!.displayName,
    );
    isRequestingExpert = false;
    res.fold(
      (_) {
        expertRequestSent = true;
      },
      (_) {
        errorCode = UiMessage.sendRequestFailed;
      },
    );
    _safeNotify();
  }
}
