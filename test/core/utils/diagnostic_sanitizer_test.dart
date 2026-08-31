import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/config/app_secrets.dart';
import 'package:cropguard_flutter/core/utils/diagnostic_sanitizer.dart';

void main() {
  group('DiagnosticSanitizer', () {
    setUp(() {
      AppSecrets.reset();
      AppSecrets.dartDefineGeminiApiKeyOverride =
          'AIzaSyFakeGeminiKey1234567890abcdefgh';
      AppSecrets.dartDefineGhanaNlpKeyOverride =
          'ghana_nlp_secret_token_abcdef';
    });

    tearDown(() {
      AppSecrets.reset();
    });

    test('redacts configured AppSecrets values', () {
      const log =
          'Connecting with gemini key AIzaSyFakeGeminiKey1234567890abcdefgh and ghana key ghana_nlp_secret_token_abcdef';
      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean.contains('AIzaSyFakeGeminiKey1234567890abcdefgh'), isFalse);
      expect(clean.contains('ghana_nlp_secret_token_abcdef'), isFalse);
      expect(clean, contains('[REDACTED_SECRET]'));
    });

    test('redacts generic Google API keys and Bearer tokens', () {
      const log =
          'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 and API Key AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean, contains('Bearer [REDACTED_TOKEN]'));
      expect(clean, contains('[REDACTED_API_KEY]'));
    });

    test('redacts key/token/password assignments in queries or json', () {
      const log =
          'https://api.com?password=mySecretPassword123&api_key=secretKey999&access_token=token456';
      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean.contains('mySecretPassword123'), isFalse);
      expect(clean.contains('secretKey999'), isFalse);
      expect(clean.contains('token456'), isFalse);
      expect(clean, contains('password=[REDACTED_CREDENTIAL]'));
      expect(clean, contains('api_key=[REDACTED_CREDENTIAL]'));
    });

    test('redacts personal email addresses and Ghanaian phone numbers', () {
      const log =
          'Contact farmer at farmer.kofi@gmail.com or call +233241234567 or 0244123456';
      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean.contains('farmer.kofi@gmail.com'), isFalse);
      expect(clean.contains('+233241234567'), isFalse);
      expect(clean.contains('0244123456'), isFalse);
      expect(clean, contains('[REDACTED_EMAIL]'));
      expect(clean, contains('[REDACTED_PHONE]'));
    });

    test('coarsens high-precision farm coordinates in text to 2 decimals', () {
      const log =
          'Outbreak at latitude: 5.60371689 and longitude: -0.18696432, coords: (6.123456, -1.987654)';
      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean, contains('latitude: 5.60'));
      expect(clean, contains('longitude: -0.19'));
      expect(clean, contains('(6.12, -1.99)'));
      expect(clean.contains('5.60371689'), isFalse);
      expect(clean.contains('-0.18696432'), isFalse);
    });

    test('redacts Base64 image data URIs and long base64 buffers', () {
      final fakeDataUri = 'data:image/jpeg;base64,${'A' * 200}';
      final fakeRawBlob = 'B' * 100;
      final log = 'Received payload $fakeDataUri and binary $fakeRawBlob';

      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean, contains('[BASE64_IMAGE_DATA_REDACTED len='));
      expect(clean, contains('[BASE64_PAYLOAD_REDACTED len=100]'));
      expect(clean.contains('A' * 50), isFalse);
      expect(clean.contains('B' * 50), isFalse);
    });

    test('redacts large byte array dumps', () {
      const log =
          'Raw bytes: [255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1]';
      final clean = DiagnosticSanitizer.sanitizeString(log);

      expect(clean, contains('[BYTE_BUFFER_REDACTED]'));
    });

    test('sanitizeMap sanitizes values and coarsens coordinate fields', () {
      final map = <String, Object?>{
        'user_email': 'test@example.com',
        'latitude': 5.60371689,
        'longitude': -0.18696432,
        'disease': 'Cocoa Black Pod',
        'auth': 'Bearer secret_token_123',
      };

      final cleanMap = DiagnosticSanitizer.sanitizeMap(map);

      expect(cleanMap['user_email'], '[REDACTED_EMAIL]');
      expect(cleanMap['latitude'], '5.60');
      expect(cleanMap['longitude'], '-0.19');
      expect(cleanMap['disease'], 'Cocoa Black Pod');
      expect(cleanMap['auth'], contains('[REDACTED_TOKEN]'));
    });

    test('sanitizeError returns a SanitizedDiagnosticException with clean text',
        () {
      final rawException = Exception(
          'Failed connecting with key=secretApiKey987 to user test@example.com');
      final cleanErr = DiagnosticSanitizer.sanitizeError(rawException);

      expect(cleanErr, isA<SanitizedDiagnosticException>());
      final str = cleanErr.toString();
      expect(str.contains('secretApiKey987'), isFalse);
      expect(str.contains('test@example.com'), isFalse);
      expect(str, contains('[REDACTED_CREDENTIAL]'));
      expect(str, contains('[REDACTED_EMAIL]'));
    });
  });
}
