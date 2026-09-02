import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failures.dart';
import '../../core/utils/retry_utils.dart';

/// Uploads local files to Supabase Storage bucket ('cropguard-media')
class SupabaseStorageService {
  final SupabaseClient _client;
  static const String defaultBucket = 'cropguard-media';

  SupabaseStorageService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  bool _isStorageTransientError(Object error) {
    if (error is StorageException) {
      final code = error.statusCode;
      if (code == '500' || code == '503' || code == '504' || code == '429') {
        return true;
      }
    }
    return error is TimeoutException || error is SocketException;
  }

  Future<String> uploadCommunityImage({
    required String localPath,
    required String userId,
    String bucket = defaultBucket,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw ServerFailure('Image file not found at $localPath');
    }
    final ext = localPath.contains('.') ? localPath.split('.').last : 'jpg';
    final path = 'community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    try {
      return await RetryUtils.retry(
        () async {
          await _client.storage.from(bucket).upload(
                path,
                file,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );
          return _client.storage.from(bucket).getPublicUrl(path);
        },
        maxAttempts: 3,
        timeout: const Duration(seconds: 30),
        retryIf: _isStorageTransientError,
      );
    } catch (e) {
      throw ServerFailure('Supabase Storage upload failed: $e');
    }
  }

  Future<String> uploadProfileImage({
    required String localPath,
    required String userId,
    String bucket = defaultBucket,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw ServerFailure('Image file not found at $localPath');
    }
    final ext = localPath.contains('.') ? localPath.split('.').last : 'jpg';
    final path = 'profiles/$userId/avatar.$ext';

    try {
      return await RetryUtils.retry(
        () async {
          await _client.storage.from(bucket).upload(
                path,
                file,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );
          return _client.storage.from(bucket).getPublicUrl(path);
        },
        maxAttempts: 3,
        timeout: const Duration(seconds: 30),
        retryIf: _isStorageTransientError,
      );
    } catch (e) {
      throw ServerFailure('Supabase Profile photo upload failed: $e');
    }
  }
}
