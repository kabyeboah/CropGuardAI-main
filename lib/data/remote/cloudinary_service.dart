import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_secrets.dart';
import '../../core/error/failures.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/retry_utils.dart';

/// Uploads community images to Cloudinary (unsigned preset).
/// Configure CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET via
/// --dart-define or the .env file — never commit real values in source.
class CloudinaryService {
  static const Duration _timeout = Duration(seconds: 30);

  String get _cloudName => AppSecrets.cloudinaryCloudName;
  String get _uploadPreset => AppSecrets.cloudinaryUploadPreset;

  /// Throws if the credentials are not configured via env or --dart-define.
  void ensureConfigured() {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw StateError(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET via --dart-define or the .env file.',
      );
    }
  }

  /// Uploads [localPath] and returns the HTTPS [secure_url], or throws with
  /// Cloudinary's error message when the API rejects the request.
  Future<String> uploadImage(String localPath) async {
    ensureConfigured();
    final rawFile = File(localPath);
    if (!await rawFile.exists()) {
      throw ServerFailure('Image file not found at $localPath.');
    }

    final compressed = await ImageCompressor.compressImage(rawFile);
    final uploadPath = compressed.path;

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    try {
      final secureUrl = await RetryUtils.retry(() async {
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', uploadPath));

        final streamed = await request.send().timeout(_timeout);
        final body = await streamed.stream.bytesToString().timeout(_timeout);

        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          throw Exception(_parseErrorMessage(body) ??
              'Upload failed (HTTP ${streamed.statusCode}).');
        }

        final json = jsonDecode(body) as Map<String, dynamic>;
        final url = json['secure_url'] as String?;
        if (url == null || url.isEmpty) {
          throw Exception('Upload succeeded but no secure_url was returned.');
        }
        return url;
      }, maxAttempts: 3, timeout: const Duration(seconds: 40));
      
      return secureUrl;
    } catch (e) {
      final sanitizedErr = _sanitize(e.toString());
      throw ServerFailure('Cloudinary upload failed: $sanitizedErr');
    }
  }

  String? _parseErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String?;
      }
      if (error is String) return error;
    } catch (_) {
      // Not JSON — fall through.
    }
    return null;
  }

  String _sanitize(String input) {
    var sanitized = input;
    if (_cloudName.isNotEmpty) {
      sanitized = sanitized.replaceAll(_cloudName, '***');
    }
    if (_uploadPreset.isNotEmpty) {
      sanitized = sanitized.replaceAll(_uploadPreset, '***');
    }
    return sanitized;
  }
}
