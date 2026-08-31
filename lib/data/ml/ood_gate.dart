import 'dart:typed_data';

/// Out-of-Distribution (OOD) detection gate interface.
///
/// Intended architecture: A dedicated binary leaf/non-leaf filter or
/// penultimate-layer feature embedding distance estimator (e.g., Mahalanobis
/// distance against known crop training centroids) that rejects non-leaf/non-plant
/// inputs before full multi-class pathology inference.
abstract class OODGate {
  /// Evaluates whether the image at [imagePath] represents a supported crop leaf.
  Future<bool> isPlantImage(String imagePath);

  /// Evaluates whether raw RGBA camera frame bytes represent a supported crop leaf.
  Future<bool> isPlantBytes(Uint8List rgbaBytes, int width, int height);
}

/// Default OOD gate implementation using honest scoping.
///
/// **Architectural Status & Documented Confidence Abstention Mechanism:**
/// A standalone binary leaf/non-leaf TFLite neural model is not bundled in this release.
/// [AlwaysAcceptOODGate] passes inputs to the primary classifier without pretending
/// an unvalidated heuristic is an OOD classifier.
///
/// **Active Safeguards & Confidence Abstention:**
/// - **Temperature-Calibrated Confidence Threshold ($\tau = 0.60$):**
///   Inferences scoring below 0.60 confidence trigger automatic diagnostic abstention.
///   These scans are routed to [LowConfidenceScreen] and auto-trigger multimodal
///   Gemini Cloud AI pathology audits, multi-angle soft voting, and human agronomist escalation.
/// - **Image Quality Analyzer:**
///   Pre-inference checks reject blurry, underexposed, or overexposed inputs before model inference.
/// - **Downstream UI Disclaimers:**
///   User-facing notices in [LowConfidenceScreen] and [ResultScreen] explicitly advise
///   users on the diagnostic scope and emphasize that diagnoses are advisory.
class AlwaysAcceptOODGate implements OODGate {
  @override
  Future<bool> isPlantImage(String imagePath) async => true;

  @override
  Future<bool> isPlantBytes(Uint8List rgbaBytes, int width, int height) async =>
      true;
}
