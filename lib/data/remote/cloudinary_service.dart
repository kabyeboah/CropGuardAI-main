import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_secrets.dart';

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
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Image file not found.');
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', localPath));

    final streamed = await request.send().timeout(_timeout);
    // Bound the body read too — `.timeout` on send() does not cover a server
    // that sends headers then stalls mid-stream.
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
}
