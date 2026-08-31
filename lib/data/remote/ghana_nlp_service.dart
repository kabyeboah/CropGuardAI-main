import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_secrets.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/retry_utils.dart';
import '../../core/error/failures.dart';
import 'cloud_functions_service.dart';

/// ── Khaya AI API Version Constants ──────────────────────────────────────
/// These constants are the single source of truth for the Flutter client.
/// Any future version migration: change the constant here ONLY.
/// NEVER hard-code a version string in request URLs.
///
/// ASR v1 and v2 are DEPRECATED. TTS v1 is DEPRECATED. Translation v1 is DEPRECATED.
class KhayaApiVersions {
  KhayaApiVersions._();
  static const String asrVersion = 'v3'; // ASR v1, v2 are DEPRECATED
  static const String ttsVersion = 'v2'; // TTS v1 is DEPRECATED
  static const String translationVersion = 'v2'; // Translation v1 is DEPRECATED
}


/// Ghana NLP / Khaya AI TTS / ASR / Translation Service.
///
/// Architecture:
/// - In production: Proxies all requests through authenticated
///   backend [CloudFunctionsService] where GHANA_NLP_SUBSCRIPTION_KEY
///   is kept in GCP Secret Manager — never in the Flutter client.
/// - In local debug / testing: Falls back to direct HTTP API if
///   subscription key is configured via --dart-define or .env.
///
/// API Versions:
///   ASR: v3  (ASR v1 and v2 are DEPRECATED — never use)
///   TTS: v2  (TTS v1 is DEPRECATED — never use)
///   Translation: v2  (Translation v1 is DEPRECATED — never use)
class GhanaNlpService {
  final String _baseUrl = 'https://translation-api.ghananlp.org';
  CloudFunctionsService? _functions;

  static final GhanaNlpService _instance = GhanaNlpService._internal();
  factory GhanaNlpService({CloudFunctionsService? functions}) {
    if (functions != null) {
      _instance._functions = functions;
    }
    return _instance;
  }
  GhanaNlpService._internal();

  void setCloudFunctionsService(CloudFunctionsService functions) {
    _functions = functions;
  }

  String? get _subscriptionKey => AppSecrets.ghanaNlpSubscriptionKey;

  /// Text-to-Speech: Synthesizes text into audio
  Future<File?> synthesize(String text, {String language = 'tw'}) async {
    if (text.trim().isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final fileName = 'tts_${text.hashCode}_$language.wav';
    final file = File('${dir.path}/$fileName');

    // Local Disk Cache Check
    if (await file.exists()) {
      AppLogger.d('Ghana NLP TTS disk cache hit for: "$text" ($language)');
      return file;
    }

    // 1. Primary Route: Backend Cloud Function Proxy
    final functions = _functions;
    if (functions != null) {
      try {
        final audioBytes = await functions.synthesizeGhanaNlp(
          text: text,
          language: language,
        );
        if (audioBytes.isNotEmpty) {
          await file.writeAsBytes(audioBytes);
          AppLogger.d(
              'Ghana NLP TTS backend proxy synthesis success for: "$text"');
          return file;
        }
      } catch (e) {
        AppLogger.w(
            'Ghana NLP TTS backend proxy failed ($e). Checking direct client fallback.');
      }
    }

    // 2. Secondary / Local Development Fallback: Direct Client HTTP API
    // Uses TTS v2 — DO NOT revert to /tts/v1 (deprecated)
    final key = _subscriptionKey;
    if (key == null || key.isEmpty) {
      AppLogger.w(
          'Ghana NLP TTS skipped: subscription key not configured on client and backend proxy unavailable');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await RetryUtils.retry(
        () => http.post(
          Uri.parse('$_baseUrl/tts/${KhayaApiVersions.ttsVersion}/synthesize'),
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
        timeout: const Duration(seconds: 20),
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

  /// Automatic Speech Recognition (ASR): Transcribes binary audio to text
  Future<String?> transcribe(File audioFile, {String language = 'tw'}) async {
    if (!await audioFile.exists()) {
      AppLogger.w('Ghana NLP ASR skipped: audio file does not exist');
      return null;
    }

    final bytes = await audioFile.readAsBytes();

    // 1. Primary Route: Backend Cloud Function Proxy
    final functions = _functions;
    if (functions != null) {
      try {
        final text = await functions.transcribeGhanaNlp(
          audioBytes: bytes,
          language: language,
        );
        if (text.isNotEmpty) {
          AppLogger.d(
              'Ghana NLP ASR backend proxy transcription success: "$text"');
          return text;
        }
      } catch (e) {
        AppLogger.w(
            'Ghana NLP ASR backend proxy failed ($e). Checking direct client fallback.');
      }
    }

    // 2. Secondary / Local Development Fallback: Direct Client HTTP API
    // Uses ASR v3 — DO NOT revert to /asr/v2 or /asr/v1 (both deprecated)
    final key = _subscriptionKey;
    if (key == null || key.isEmpty) {
      AppLogger.w(
          'Ghana NLP ASR skipped: subscription key not configured on client and backend proxy unavailable');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(
          '$_baseUrl/asr/${KhayaApiVersions.asrVersion}/transcribe?language=$language');

      final response = await RetryUtils.retry(
        () => http.post(
          uri,
          headers: {
            'Content-Type': 'audio/wav',
            'Ocp-Apim-Subscription-Key': key,
          },
          body: bytes,
        ),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        String text = response.body.trim();
        // If response is JSON object e.g. {"text": "..."}, extract field
        if (text.startsWith('{') && text.endsWith('}')) {
          try {
            final decoded = jsonDecode(text);
            if (decoded is Map && decoded.containsKey('text')) {
              text = decoded['text']?.toString().trim() ?? text;
            }
          } catch (_) {}
        }
        // Remove enclosing quotes if present
        if (text.startsWith('"') && text.endsWith('"') && text.length > 1) {
          text = text.substring(1, text.length - 1).trim();
        }
        AppLogger.d(
            'Ghana NLP ASR success (${stopwatch.elapsedMilliseconds}ms): "$text"');
        return text;
      } else {
        throw Exception(
            'ASR API returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      final sanitizedErr = _sanitize(e.toString());
      AppLogger.e('Ghana NLP ASR exception', sanitizedErr, stack);
      throw ServerFailure('Ghana NLP ASR transcription failed: $sanitizedErr');
    }
  }

  String _getSpeakerId(String lang) {
    // Centralised speaker ID mapping.
    // Update here (and in docs/api/KHAYA_API_CONTRACT.md) when provider adds voices.
    switch (lang) {
      case 'tw':
        return 'twi_speaker_4';
      case 'ee':
        return 'ewe_speaker_1';
      case 'dag':
        return 'dagbani_speaker_1';
      default:
        // Attempt a generic pattern; provider will return 400 if unsupported.
        return '${lang}_speaker_1';
    }
  }

  /// Translates [text] using Khaya AI Translation API v2.
  ///
  /// [languagePair] format: `<source>-<target>` (e.g. `en-tw`, `tw-en`).
  /// Returns null when translation is unavailable (offline or key missing).
  /// Throws [ServerFailure] on provider error.
  Future<String?> translate(
    String text, {
    required String languagePair,
  }) async {
    if (text.isEmpty) return null;

    // Guard: same language — skip remote call
    final parts = languagePair.split('-');
    if (parts.length == 2 && parts[0] == parts[1]) return text;

    // 1. Primary Route: Backend Cloud Function Proxy
    final functions = _functions;
    if (functions != null) {
      try {
        final translated = await functions.translateGhanaNlp(
          text: text,
          languagePair: languagePair,
        );
        if (translated.isNotEmpty) {
          AppLogger.d(
              'Ghana NLP Translation backend proxy success: "$translated" [$languagePair]');
          return translated;
        }
      } catch (e) {
        AppLogger.w(
            'Ghana NLP Translation backend proxy failed ($e). Checking direct client fallback.');
      }
    }

    // 2. Secondary / Local Development Fallback: Direct Client HTTP API
    // Uses Translation v2 — DO NOT use deprecated v1 endpoint.
    final key = _subscriptionKey;
    if (key == null || key.isEmpty) {
      AppLogger.w(
          'Ghana NLP Translation skipped: subscription key not configured on client and backend proxy unavailable');
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await RetryUtils.retry(
        () => http.post(
          Uri.parse('$_baseUrl/translate'),
          headers: {
            'Content-Type': 'application/json',
            'Ocp-Apim-Subscription-Key': key,
          },
          body: jsonEncode({
            'in': text,
            'lang': languagePair,
          }),
        ),
        maxAttempts: 2,
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        String result = response.body.trim();
        // Handle JSON or plain-string response
        if (result.startsWith('{') && result.endsWith('}')) {
          try {
            final decoded = jsonDecode(result);
            if (decoded is Map) {
              result = (decoded['translatedText'] ??
                      decoded['translation'] ??
                      decoded['out'] ??
                      decoded['result'] ??
                      decoded['text'] ??
                      result)
                  .toString()
                  .trim();
            }
          } catch (_) {}
        }
        if (result.startsWith('"') &&
            result.endsWith('"') &&
            result.length > 1) {
          result = result.substring(1, result.length - 1).trim();
        }
        AppLogger.d(
            'Ghana NLP Translation success (${stopwatch.elapsedMilliseconds}ms): "$result"');
        return result;
      } else {
        throw Exception(
            'Translation API returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      final sanitizedErr = _sanitize(e.toString());
      AppLogger.e('Ghana NLP Translation exception', sanitizedErr, stack);
      throw ServerFailure('Ghana NLP Translation failed: $sanitizedErr');
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
