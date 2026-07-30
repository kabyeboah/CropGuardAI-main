import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import '../../core/utils/retry_utils.dart';
import '../../core/error/failures.dart';

/// Uploads local files to Firebase Storage for community and scan assets.
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadCommunityImage({
    required String localPath,
    required String userId,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw ServerFailure('Image file not found at $localPath');
    }
    final ext = localPath.contains('.') ? localPath.split('.').last : 'jpg';
    final ref = _storage.ref().child(
      'community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext',
    );

    try {
      return await RetryUtils.retry(() async {
        await ref.putFile(file);
        return await ref.getDownloadURL();
      }, maxAttempts: 3, timeout: const Duration(seconds: 30));
    } catch (e) {
      throw ServerFailure('Firebase Storage upload failed: $e');
    }
  }
}
