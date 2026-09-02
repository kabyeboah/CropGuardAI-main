import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/config/app_secrets.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/cloud_ai_analysis_result.dart';
import 'cloud_functions_service.dart';

/// Exception thrown when Gemini Cloud AI inference fails.
class GeminiCloudAiException implements Exception {
  final String message;
  const GeminiCloudAiException(this.message);

  @override
  String toString() => 'GeminiCloudAiException: $message';
}

/// Service providing secondary / fallback multimodal crop disease diagnosis using Gemini 1.5 Flash.
///
/// Architecture:
/// - In production: Proxies requests through authenticated backend [CloudFunctionsService] / Supabase Edge Functions.
/// - In local debug / testing: Falls back to direct on-client [GenerativeModel] if an API key is
///   explicitly provided via AppSecrets / .env.
class GeminiCloudAiService {
  final CloudFunctionsService? _functions;

  GeminiCloudAiService({
    CloudFunctionsService? functions,
  }) : _functions = functions;

  /// Retrieves the active Gemini API key from AppSecrets.
  String _getApiKey() {
    final key = AppSecrets.geminiApiKey;
    if (key != null && key.isNotEmpty) {
      return key;
    }
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    return '';
  }

  /// Analyzes a crop leaf image file using Gemini 1.5 Flash multimodal vision model.
  Future<CloudAiAnalysisResult> analyzeCropImage({
    required String imagePath,
    String? cropType,
    List<String>? initialTopCandidates,
  }) async {
    final apiKey = _getApiKey();
    if (_functions == null && apiKey.isEmpty) {
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
    // 1. Primary Production Route: Authenticated Backend Cloud Function Proxy
    final functions = _functions;
    if (functions != null) {
      try {
        final imageBase64 = base64Encode(imageBytes);
        final rawResult = await functions.analyzeCropWithGemini(
          imageBase64: imageBase64,
          cropType: cropType,
          initialTopCandidates: initialTopCandidates,
        );
        return CloudAiAnalysisResult.fromJson(rawResult);
      } catch (e) {
        AppLogger.w(
            'GeminiCloudAiService: Backend Cloud Function proxy failed or unauthenticated ($e). Checking direct client fallback.');
        // Continue to direct fallback if a direct key is configured in dev/testing
      }
    }

    // 2. Secondary / Local Development Fallback: Direct Client GenerativeModel
    final apiKey = _getApiKey();
    if (apiKey.isEmpty) {
      throw const GeminiCloudAiException(
          'Gemini API key is not configured. Please set gemini_api_key in Firebase Remote Config.');
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );

      final candidateInfo = (initialTopCandidates != null &&
              initialTopCandidates.isNotEmpty)
          ? "On-device preliminary model candidates: ${initialTopCandidates.join(', ')}."
          : "";
      final cropContext = (cropType != null && cropType.isNotEmpty)
          ? "Crop Type: $cropType."
          : "";

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

      final response = await model.generateContent(content).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw const GeminiCloudAiException(
              'Gemini Cloud AI request timed out after 60 seconds. Please check your network connection.');
        },
      );
      final text = response.text;

      if (text == null || text.trim().isEmpty) {
        throw const GeminiCloudAiException(
            'Empty response received from Gemini Cloud AI.');
      }

      final cleanJsonText =
          text.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();
      final Map<String, dynamic> jsonMap =
          jsonDecode(cleanJsonText) as Map<String, dynamic>;

      return CloudAiAnalysisResult.fromJson(jsonMap);
    } catch (e, st) {
      AppLogger.e(
          'GeminiCloudAiService error during image analysis: $e', e, st);
      if (e is GeminiCloudAiException) rethrow;
      throw GeminiCloudAiException('Gemini Cloud AI analysis failed: $e');
    }
  }
}
