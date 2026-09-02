import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_secrets.dart';
import '../../core/error/failures.dart';
import '../../core/utils/retry_utils.dart';

/// CloudFunctionsService (Supabase Edge Functions Client) — executes trusted server-side
/// routines for multimodal Gemini diagnosis, GhanaNLP voice/translation, and account purge.
class CloudFunctionsService {
  final http.Client _client;
  final Future<String?> Function()? _authTokenProvider;
  final String _baseUrl;

  CloudFunctionsService({
    http.Client? client,
    Future<String?> Function()? authTokenProvider,
    String? baseUrl,
    String? projectId,
  })  : _client = client ?? http.Client(),
        _authTokenProvider = authTokenProvider,
        _baseUrl = baseUrl ?? '${AppSecrets.supabaseUrl}/functions/v1';

  Future<String?> _getAuthToken() async {
    final provider = _authTokenProvider;
    if (provider != null) {
      return provider();
    }
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Uri _getFunctionUri(String functionName) {
    return Uri.parse('$_baseUrl/$functionName');
  }

  Future<Map<String, dynamic>> _callFunction({
    required String functionName,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final idToken = await _getAuthToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure(
          'User must be signed in to perform this operation.');
    }

    final uri = _getFunctionUri(functionName);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
      'apikey': AppSecrets.supabaseAnonKey,
    };

    final body = jsonEncode(data);

    try {
      final response = await RetryUtils.retry(
        () => _client.post(uri, headers: headers, body: body),
        maxAttempts: 3,
        timeout: timeout,
        retryIf: (e) => e is TimeoutException || e is SocketException,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(decodedBody);
        if (decoded is Map<String, dynamic>) {
          final res = decoded['result'];
          if (res is Map<String, dynamic>) return res;
          return decoded;
        }
        return {'success': true};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthFailure('Unauthorized request to $functionName.');
      } else if (response.statusCode == 404) {
        throw ServerFailure('Backend function $functionName not found.');
      } else {
        throw ServerFailure(
            '$functionName returned status ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to call $functionName backend: $e');
    }
  }

  /// Calls the trusted backend `verifyOutbreak` Cloud Function.
  /// Enforces server-side authentication and idempotency against duplicate voting.
  Future<Map<String, dynamic>> verifyOutbreak({
    required String reportId,
    required bool confirm,
  }) async {
    return _callFunction(
      functionName: 'verify-outbreak',
      data: {
        'reportId': reportId,
        'confirm': confirm,
      },
    );
  }

  /// Calls the trusted Supabase `analyze-crop` Edge Function.
  /// Securely proxies crop pathology diagnosis using server-held GEMINI_API_KEY.
  Future<Map<String, dynamic>> analyzeCropWithGemini({
    required String imageBase64,
    String? cropType,
    List<String>? initialTopCandidates,
  }) async {
    final res = await _callFunction(
      functionName: 'analyze-crop',
      data: {
        'imageBase64': imageBase64,
        if (cropType != null) 'cropType': cropType,
        if (initialTopCandidates != null)
          'initialTopCandidates': initialTopCandidates,
      },
      timeout: const Duration(seconds: 30),
    );
    return res['result'] as Map<String, dynamic>? ?? res;
  }

  /// Calls the trusted Supabase `khaya-tts` Edge Function.
  /// Returns decoded audio bytes without exposing GHANA_NLP_SUBSCRIPTION_KEY.
  Future<Uint8List> synthesizeGhanaNlp({
    required String text,
    required String language,
  }) async {
    final res = await _callFunction(
      functionName: 'khaya-tts',
      data: {
        'text': text,
        'language': language,
      },
      timeout: const Duration(seconds: 20),
    );
    final audioBase64 = res['audioBase64'] as String?;
    if (audioBase64 == null || audioBase64.isEmpty) {
      throw const ServerFailure(
          'No audio data received from backend synthesis.');
    }
    return base64Decode(audioBase64);
  }

  /// Calls the trusted Supabase `khaya-asr` Edge Function (ASR v3).
  /// Returns transcription text without exposing GHANA_NLP_SUBSCRIPTION_KEY.
  Future<String> transcribeGhanaNlp({
    required Uint8List audioBytes,
    required String language,
  }) async {
    final audioBase64 = base64Encode(audioBytes);
    final res = await _callFunction(
      functionName: 'khaya-asr',
      data: {
        'audioBase64': audioBase64,
        'language': language,
      },
      timeout: const Duration(seconds: 30),
    );
    return res['transcription'] as String? ?? '';
  }

  /// Calls the trusted Supabase `khaya-translate` Edge Function (Translation v2).
  /// Returns translated text without exposing GHANA_NLP_SUBSCRIPTION_KEY.
  ///
  /// [languagePair] format: `<source>-<target>` (e.g. `en-tw`, `tw-en`).
  Future<String> translateGhanaNlp({
    required String text,
    required String languagePair,
  }) async {
    final res = await _callFunction(
      functionName: 'khaya-translate',
      data: {
        'text': text,
        'languagePair': languagePair,
      },
      timeout: const Duration(seconds: 15),
    );
    return res['translation'] as String? ?? '';
  }

  /// Calls the trusted Supabase `delete-account` Edge Function to purge user profile and data.
  Future<void> deleteAccount() async {
    await _callFunction(
      functionName: 'delete-account',
      data: {},
      timeout: const Duration(seconds: 15),
    );
  }
}
