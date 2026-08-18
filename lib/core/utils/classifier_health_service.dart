import 'package:flutter/foundation.dart';

/// Tracks ML classifier engine health and telemetry across inference runs.
class ClassifierHealthService extends ChangeNotifier {
  bool _isHealthy = true;
  String? _modelVersion;
  int _lastInferenceMs = 0;
  int _fallbackCount = 0;

  bool get isHealthy => _isHealthy;
  String? get modelVersion => _modelVersion;
  int get lastInferenceMs => _lastInferenceMs;
  int get fallbackCount => _fallbackCount;

  void updateHealth({
    required bool isHealthy,
    String? modelVersion,
    int? inferenceMs,
    bool usedFallback = false,
  }) {
    _isHealthy = isHealthy;
    if (modelVersion != null) _modelVersion = modelVersion;
    if (inferenceMs != null) _lastInferenceMs = inferenceMs;
    if (usedFallback) _fallbackCount++;
    notifyListeners();
  }

  void resetFallbackCount() {
    _fallbackCount = 0;
    notifyListeners();
  }
}
