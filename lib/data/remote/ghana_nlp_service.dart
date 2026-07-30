import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_secrets.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/retry_utils.dart';
import '../../core/error/failures.dart';

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

    final dir = await getTemporaryDirectory();
    final fileName = 'tts_${text.hashCode}_$language.wav';
    final file = File('${dir.path}/$fileName');

    // Local Disk Cache Check
    if (await file.exists()) {
      AppLogger.d('Ghana NLP TTS disk cache hit for: "$text" ($language)');
      return file;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await RetryUtils.retry(
        () => http.post(
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
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        AppLogger.d(
            'Ghana NLP TTS success: ${stopwatch.elapsedMilliseconds}ms');
        return file;
      } else {
        throw Exception(
            'TTS API returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      final sanitizedErr = _sanitize(e.toString());
      AppLogger.e('Ghana NLP TTS exception', sanitizedErr, stack);
      throw ServerFailure('Ghana NLP TTS synthesis failed: $sanitizedErr');
    }
  }

  String _getSpeakerId(String lang) {
    switch (lang) {
      case 'tw': return 'twi_speaker_4';
      case 'ee': return 'ewe_speaker_1';
      case 'dag': return 'dagbani_speaker_1';
      default: return '${lang}_speaker_1';
    }
  }

  String _sanitize(String input) {
    final key = _subscriptionKey;
    if (key != null && key.isNotEmpty) {
      return input.replaceAll(key, '***');
    }
    return input;
  }
}
