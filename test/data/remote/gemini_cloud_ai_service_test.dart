import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/domain/models/cloud_ai_analysis_result.dart';
import 'package:cropguard_flutter/data/remote/gemini_cloud_ai_service.dart';

void main() {
  group('CloudAiAnalysisResult Tests', () {
    test('fromJson parses valid Gemini JSON response correctly', () {
      final json = {
        'label': 'Cassava Mosaic Disease',
        'confidence': 0.92,
        'isHealthy': false,
        'symptoms': ['Yellow mottling', 'Leaf distortion'],
        'rootCause': 'Cassava mosaic geminivirus transmitted by whiteflies.',
        'organicRemedies': ['Use virus-free planting cuttings', 'Control whitefly population'],
        'preventionTips': ['Plant resistant varieties', 'Rogue infected plants early'],
        'rawReasoning': 'Clear chlorotic patterns on cassava leaves.',
      };

      final result = CloudAiAnalysisResult.fromJson(json);

      expect(result.label, equals('Cassava Mosaic Disease'));
      expect(result.confidence, equals(0.92));
      expect(result.isHealthy, isFalse);
      expect(result.symptoms.length, equals(2));
      expect(result.rootCause, contains('geminivirus'));
      expect(result.organicRemedies, contains('Use virus-free planting cuttings'));
      expect(result.isFallback, isFalse);
    });

    test('fromJson handles missing optional fields with safe defaults', () {
      final json = <String, dynamic>{};

      final result = CloudAiAnalysisResult.fromJson(json);

      expect(result.label, equals('Unknown Crop Disease'));
      expect(result.confidence, equals(0.85));
      expect(result.isHealthy, isFalse);
      expect(result.symptoms, isEmpty);
      expect(result.rootCause, isEmpty);
      expect(result.organicRemedies, isEmpty);
      expect(result.preventionTips, isEmpty);
    });
  });

  group('GeminiCloudAiService Exception Tests', () {
    test('throws GeminiCloudAiException when API key is missing', () async {
      final service = GeminiCloudAiService();

      expect(
        () => service.analyzeCropImage(imagePath: '/non/existent/path.jpg'),
        throwsA(isA<GeminiCloudAiException>()),
      );
    });
  });
}
