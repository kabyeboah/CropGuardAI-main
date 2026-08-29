import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import '../../core/error/failures.dart';
import '../../core/utils/retry_utils.dart';

/// Uploads local files to Firebase Storage for community and scan assets.
class FirebaseStorageService {
  final FirebaseStorage _storage;

  FirebaseStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  bool _isStorageTransientError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
        case 'internal':
        case 'retry-limit-exceeded':
        case 'network-request-failed':
        case 'service-unavailable':
        case 'too-many-requests':
          return true;
        default:
          return false;
      }
    }
    return error is TimeoutException || error is SocketException;
  }

  Future<String> uploadCommunityImage({
    required String localPath,
    required String userId,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw ServerFailure('Image file not found at $localPath');
    }
    final ext = localPath.contains('.') ? localPath.split('.').last : 'jpg';
    final ref = _storage.ref().child(
      'community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext',
    );

    try {
      return await RetryUtils.retry(
        () async {
          await ref.putFile(file);
          return await ref.getDownloadURL();
        },
        maxAttempts: 3,
        timeout: const Duration(seconds: 30),
        retryIf: _isStorageTransientError,
      );
    } catch (e) {
      throw ServerFailure('Firebase Storage upload failed: $e');
    }
  }
}

