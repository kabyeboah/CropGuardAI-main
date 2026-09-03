import 'dart:convert';
import '../config/app_secrets.dart';

/// Central privacy and security sanitizer for logs, Crashlytics, Analytics,
/// and error diagnostic pipelines.
///
/// Ensures diagnostic telemetry does NOT leak:
/// 1. Credentials (API keys, Bearer tokens, passwords, secrets, headers).
/// 2. Personal Data (Email addresses, telephone numbers).
/// 3. Exact Farm Coordinates (high precision GPS floats are coarsened to 2 decimal places ~1.1km).
/// 4. Image content & binary buffers (raw Base64 payloads, data URIs, byte arrays).
class DiagnosticSanitizer {
  DiagnosticSanitizer._();

  // ── Regex patterns ──────────────────────────────────────────────────────────

  // Emails
  static final RegExp _emailRegex = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
    caseSensitive: false,
  );

  // Phone numbers (Ghanaian +233 / 02x / 05x / 03x and generic international 10-15 digit formats)
  static final RegExp _phoneRegex = RegExp(
    r'(?:(?:\+233|00233|0)(?:20|23|24|25|26|27|28|50|54|55|56|57|59|30|31|32|33|34|35|36|37|38|39)[0-9]{7})\b|\b(?:\+?[1-9]\d{1,2}[ -]?)?\(?\d{3}\)?[ -]?\d{3}[ -]?\d{4}\b',
  );

  // Bearer / Authorization headers
  static final RegExp _bearerRegex = RegExp(
    r'(?:Bearer\s+|Authorization:\s*Bearer\s+|Authorization:\s*)([A-Za-z0-9\-_\.=]+)',
    caseSensitive: false,
  );

  // Generic Google / Cloud API keys (AIzaSy...)
  static final RegExp _googleApiKeyRegex = RegExp(
    r'AIza[0-9A-Za-z\-_]{28,40}',
  );

  // Generic key/token/secret assignment in URLs or strings (e.g. key=xyz, secret=abc, token=123, password=foo)
  static final RegExp _keyValueSecretRegex = RegExp(
    r"""([?&"'\s]|^)(password|secret|token|api[_-]?key|access[_-]?token|subscription[_-]?key|auth_token|auth|key)(\s*[:=]\s*["']?)([^"'&\s,;}]+)(["']?)""",
    caseSensitive: false,
  );

  // Base64 Data URIs (e.g., data:image/jpeg;base64,....)
  static final RegExp _dataUriRegex = RegExp(
    r'data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+',
    caseSensitive: false,
  );

  // Long Base64 strings (>= 64 chars continuous base64 alphabet)
  static final RegExp _rawBase64Regex = RegExp(
    r'\b[A-Za-z0-9+/]{64,}={0,2}\b',
  );

  // Large raw byte array dumps: [123, 255, 216, 45, ...]
  static final RegExp _byteArrayRegex = RegExp(
    r'\[(?:\s*\d{1,3}\s*,){9,}\s*\d{1,3}\s*\]',
  );

  // High-precision coordinates in text / key-value forms:
  // e.g. "latitude: 5.60371689", "lat=5.603716", "lat: 5.603716, lng: -0.186964", "(5.603716, -0.186964)"
  static final RegExp _coordKeyValueRegex = RegExp(
    r'(\b(?:latitude|lat|longitude|lng|lon)\b\s*[:=]\s*)(-?\d+\.\d{3,})',
    caseSensitive: false,
  );

  static final RegExp _coordTupleRegex = RegExp(
    r'\((-?\d{1,3}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})\)',
  );

  /// Sanitizes an arbitrary string message.
  static String sanitizeString(String input) {
    if (input.isEmpty) return input;
    String text = input;

    // 1. Redact known static/configured AppSecrets keys if present
    text = _redactConfiguredSecrets(text);

    // 2. Redact credentials & authorization tokens
    text = text.replaceAll(_googleApiKeyRegex, '[REDACTED_API_KEY]');
    text = text.replaceAllMapped(_bearerRegex, (m) {
      final prefix = m.group(0)!.substring(0, m.group(0)!.indexOf(m.group(1)!));
      return '$prefix[REDACTED_TOKEN]';
    });
    text = text.replaceAllMapped(_keyValueSecretRegex, (m) {
      final lead = m.group(1) ?? '';
      final keyName = m.group(2) ?? '';
      final sep = m.group(3) ?? '=';
      final trail = m.group(5) ?? '';
      return '$lead$keyName$sep[REDACTED_CREDENTIAL]$trail';
    });

    // 3. Redact Personal Identifiable Information (PII)
    text = text.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    text = text.replaceAll(_phoneRegex, '[REDACTED_PHONE]');

    // 4. Coarsen high precision farm coordinates (>2 decimals -> 2 decimals ~1.1km)
    text = text.replaceAllMapped(_coordKeyValueRegex, (m) {
      final prefix = m.group(1)!;
      final valStr = m.group(2)!;
      final d = double.tryParse(valStr);
      if (d != null) {
        return '$prefix${d.toStringAsFixed(2)}';
      }
      return '$prefix[COORDINATE_COARSENED]';
    });

    text = text.replaceAllMapped(_coordTupleRegex, (m) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null) {
        return '(${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})';
      }
      return '([COORDINATE_COARSENED], [COORDINATE_COARSENED])';
    });

    // 5. Redact image content & large binary payloads
    text = text.replaceAllMapped(_dataUriRegex, (m) {
      final len = m.group(0)?.length ?? 0;
      return '[BASE64_IMAGE_DATA_REDACTED len=$len]';
    });

    text = text.replaceAllMapped(_rawBase64Regex, (m) {
      final len = m.group(0)?.length ?? 0;
      return '[BASE64_PAYLOAD_REDACTED len=$len]';
    });

    text = text.replaceAllMapped(_byteArrayRegex, (m) {
      return '[BYTE_BUFFER_REDACTED]';
    });

    return text;
  }

  /// Sanitizes parameter maps passed to Analytics or Crashlytics custom keys.
  static Map<String, Object> sanitizeMap(Map<String, Object?> input) {
    final clean = <String, Object>{};
    for (final entry in input.entries) {
      final key = sanitizeString(entry.key);
      final value = entry.value;
      if (value == null) continue;

      if (value is String) {
        clean[key] = sanitizeString(value);
      } else if (value is num) {
        // If coordinate field names, coarsen high-precision decimals
        final lowerKey = key.toLowerCase();
        if (lowerKey.contains('lat') ||
            lowerKey.contains('lng') ||
            lowerKey.contains('lon')) {
          clean[key] = value.toDouble().toStringAsFixed(2);
        } else {
          clean[key] = value;
        }
      } else if (value is bool) {
        clean[key] = value;
      } else if (value is Map) {
        clean[key] = jsonEncode(sanitizeMap(value.cast<String, Object?>()));
      } else {
        clean[key] = sanitizeString(value.toString());
      }
    }
    return clean;
  }

  /// Sanitizes an error object for Crashlytics / logging.
  static Object sanitizeError(dynamic error) {
    if (error == null) return Exception('Unknown error');
    if (error is String) return sanitizeString(error);
    final errorStr = sanitizeString(error.toString());
    return SanitizedDiagnosticException(errorStr);
  }

  /// Sanitizes a StackTrace.
  static StackTrace? sanitizeStackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) return null;
    final clean = sanitizeString(stackTrace.toString());
    return StackTrace.fromString(clean);
  }

  static String _redactConfiguredSecrets(String input) {
    String out = input;
    final keys = <String?>[
      AppSecrets.geminiApiKey,
      AppSecrets.ghanaNlpSubscriptionKey,
      AppSecrets.cloudinaryCloudName,
      AppSecrets.cloudinaryUploadPreset,
    ];

    for (final k in keys) {
      if (k != null && k.trim().length >= 4) {
        out = out.replaceAll(k, '[REDACTED_SECRET]');
      }
    }
    return out;
  }
}

/// An Exception wrapper whose toString() contains only sanitized, privacy-safe diagnostic text.
class SanitizedDiagnosticException implements Exception {
  final String message;
  const SanitizedDiagnosticException(this.message);

  @override
  String toString() => message;
}
