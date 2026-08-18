import 'dart:convert';
import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/cloud_ai_analysis_result.dart';

/// Exception thrown when Gemini Cloud AI inference fails.
class GeminiCloudAiException implements Exception {
  final String message;
  const GeminiCloudAiException(this.message);

  @override
  String toString() => 'GeminiCloudAiException: $message';
}

/// Service providing secondary / fallback multimodal crop disease diagnosis using Gemini 1.5 Flash.
class GeminiCloudAiService {
  final FirebaseRemoteConfig? _remoteConfig;

  GeminiCloudAiService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig;

  /// Retrieves the active Gemini API key from Remote Config or build environment.
  String _getApiKey() {
    try {
      final config = _remoteConfig ?? FirebaseRemoteConfig.instance;
      final remoteKey = config.getString('gemini_api_key');
      if (remoteKey.isNotEmpty) {
        return remoteKey;
      }
    } catch (_) {
      // RemoteConfig not initialized or unavailable in test environment
    }
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    // Safe placeholder fallback for testing / unconfigured state
    AppLogger.w('GeminiCloudAiService: gemini_api_key not found in RemoteConfig or environment');
    return '';
  }

  /// Analyzes a crop leaf image file using Gemini 1.5 Flash multimodal vision model.
  Future<CloudAiAnalysisResult> analyzeCropImage({
    required String imagePath,
    String? cropType,
    List<String>? initialTopCandidates,
  }) async {
    final apiKey = _getApiKey();
    if (apiKey.isEmpty) {
      throw const GeminiCloudAiException(
          'Gemini API key is not configured. Please set gemini_api_key in Firebase Remote Config.');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw GeminiCloudAiException('Image file not found at path: $imagePath');
    }

    final bytes = await file.readAsBytes();
    return analyzeCropImageBytes(
      imageBytes: bytes,
      cropType: cropType,
      initialTopCandidates: initialTopCandidates,
    );
  }

  /// Analyzes raw crop image bytes using Gemini 1.5 Flash.
  Future<CloudAiAnalysisResult> analyzeCropImageBytes({
    required Uint8List imageBytes,
    String? cropType,
    List<String>? initialTopCandidates,
  }) async {
    final apiKey = _getApiKey();
    if (apiKey.isEmpty) {
      throw const GeminiCloudAiException(
          'Gemini API key is not configured. Please set gemini_api_key in Firebase Remote Config.');
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );

      final candidateInfo = (initialTopCandidates != null && initialTopCandidates.isNotEmpty)
          ? "On-device preliminary model candidates: ${initialTopCandidates.join(', ')}."
          : "";
      final cropContext = (cropType != null && cropType.isNotEmpty) ? "Crop Type: $cropType." : "";

      final promptText = '''
You are an expert plant pathologist and agricultural scientist specializing in West African & global crop diseases (e.g., Cocoa, Cassava, Maize, Rice, Tomato, Plantain).
Analyze this crop leaf/plant image carefully and return a JSON object with the following schema:

{
  "label": "Name of the crop disease or Healthy state (e.g. Cocoa Black Pod Disease, Cassava Mosaic Disease, Healthy Maize)",
  "confidence": 0.88,
  "isHealthy": false,
  "symptoms": ["Dark water-soaked lesions", "Fungal mycelium growth"],
  "rootCause": "Phytophthora palmivora pathogen infection accelerated by high humidity.",
  "organicRemedies": ["Apply copper-based fungicide spray", "Prune affected lower canopy leaves"],
  "preventionTips": ["Ensure adequate shade management", "Improve field drainage"],
  "rawReasoning": "Detailed visual analysis of lesions, leaf chlorosis, and texture."
}

Context:
$cropContext
$candidateInfo
Return strictly valid JSON only.
''';

      final content = [
        Content.multi([
          TextPart(promptText),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);
      final text = response.text;

      if (text == null || text.trim().isEmpty) {
        throw const GeminiCloudAiException('Empty response received from Gemini Cloud AI.');
      }

      final cleanJsonText = text.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();
      final Map<String, dynamic> jsonMap = jsonDecode(cleanJsonText) as Map<String, dynamic>;

      return CloudAiAnalysisResult.fromJson(jsonMap);
    } catch (e, st) {
      AppLogger.e('GeminiCloudAiService error during image analysis: $e', e, st);
      if (e is GeminiCloudAiException) rethrow;
      throw GeminiCloudAiException('Gemini Cloud AI analysis failed: $e');
    }
  }
}
