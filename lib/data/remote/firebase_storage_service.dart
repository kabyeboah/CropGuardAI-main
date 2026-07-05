import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads local files to Firebase Storage for community and scan assets.
class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadCommunityImage({
    required String localPath,
    required String userId,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Image file not found');
    }
    final ext = localPath.contains('.') ? localPath.split('.').last : 'jpg';
    final ref = _storage.ref().child(
      'community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
