import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_secrets.dart';
import '../../core/utils/app_logger.dart';

class GhanaNlpService {
  final String _baseUrl = 'https://translation-api.ghananlp.org';

  static final GhanaNlpService _instance = GhanaNlpService._internal();
  factory GhanaNlpService() => _instance;
  GhanaNlpService._internal();

  String? get _subscriptionKey => AppSecrets.ghanaNlpSubscriptionKey;

  /// Text-to-Speech: Synthesizes text into audio
  Future<File?> synthesize(String text, {String language = 'tw'}) async {
    final key = _subscriptionKey;
    if (key == null) {
      AppLogger.w('Ghana NLP TTS skipped: subscription key not configured');
      return null;
    }
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/tts/v1/synthesize'),
        headers: {
          'Content-Type': 'application/json',
          'Ocp-Apim-Subscription-Key': key,
        },
        body: jsonEncode({
          'text': text,
          'language': language,
          'speaker_id': _getSpeakerId(language),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = 'tts_${text.hashCode}_$language.wav';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        AppLogger.d(
            'Ghana NLP TTS success: ${stopwatch.elapsedMilliseconds}ms');
        return file;
      } else {
        AppLogger.w(
            'Ghana NLP TTS error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      AppLogger.e('Ghana NLP TTS exception', e);
      return null;
    }
  }

  String _getSpeakerId(String lang) {
    switch (lang) {
      case 'tw': return 'twi_speaker_4';
      case 'ee': return 'ewe_speaker_1'; // Assuming typical naming
      case 'dag': return 'dagbani_speaker_1';
      default: return '${lang}_speaker_1';
    }
  }
}
