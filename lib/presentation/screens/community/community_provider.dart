import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/connectivity_service.dart';
import '../../../data/remote/cloudinary_service.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../data/remote/firestore_service.dart';
import '../../../domain/models/community_post.dart';

/// Community feed: images via Cloudinary, posts in Firestore.
class CommunityProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final FirebaseAuthService _auth;
  final CloudinaryService _cloudinary;
  final ConnectivityService _connectivity;
  StreamSubscription<ConnectionStatus>? _connectivitySub;
  StreamSubscription<List<CommunityPost>>? _postsSubscription;

  CommunityProvider(this._firestore, this._auth, this._cloudinary, this._connectivity) {
    _connectivitySub = _connectivity.statusStream.listen((status) {
      connectionStatus = status;
      _safeNotify();
    });
    _connectivity.checkStatus().then((status) {
      connectionStatus = status;
      _safeNotify();
    });
    _listenToPosts();
  }

  // Route-scoped provider: stream callbacks and delayed work can fire after the
  // screen is popped. Guard every notify so it never hits a disposed object.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  List<CommunityPost> posts = [];
  String composerText = '';
  String? selectedImageUri;
  bool isPosting = false;
  bool isUploadingImage = false;
  String? errorMessage;
  // True when errorMessage was caused specifically by a Cloudinary upload
  // failure — the screen shows a Retry button in this case.
  bool uploadFailed = false;
  ConnectionStatus connectionStatus = ConnectionStatus.online;
  bool get isOffline => connectionStatus == ConnectionStatus.offline;

  void _listenToPosts() {
    _postsSubscription = _firestore.postsStream().listen(
      (p) {
        posts = p;
        _safeNotify();
      },
      onError: (_) {
        _safeNotify();
      },
    );
  }

  void onComposerChanged(String v) {
    composerText = v;
    _safeNotify();
  }

  void onImageSelected(String? uri) {
    selectedImageUri = uri;
    errorMessage = null;
    _safeNotify();
  }

  void clearSelectedImage() {
    selectedImageUri = null;
    _safeNotify();
  }

  void clearError() {
    errorMessage = null;
    uploadFailed = false;
    _safeNotify();
  }

  Future<void> postUpdate() async {
    if (composerText.trim().isEmpty) {
      errorMessage = 'Please write something before posting.';
      _safeNotify();
      return;
    }
    if (_auth.isAnonymous) {
      errorMessage = 'Guest users cannot post. Please sign in.';
      _safeNotify();
      return;
    }

    isPosting = true;
    errorMessage = null;
    _safeNotify();

    try {
      final userId = _auth.currentUserId;
      String? imageUrl;

      final localPath = selectedImageUri;
      if (localPath != null &&
          !localPath.startsWith('http://') &&
          !localPath.startsWith('https://')) {
        isUploadingImage = true;
        _safeNotify();
        try {
          imageUrl = await _cloudinary.uploadImage(localPath);
        } catch (e) {
          // Preserve composerText and selectedImageUri so the user can retry
          // without re-typing or re-selecting the image.
          uploadFailed = true;
          final msg = e.toString();
          errorMessage = msg.contains('not configured')
              ? 'Image uploads are not set up yet. Contact support.'
              : msg.contains('Upload failed') || msg.contains('not found')
                  ? msg
                  : 'Image upload failed — check your connection and tap Retry.';
          isPosting = false;
          isUploadingImage = false;
          _safeNotify();
          return;
        } finally {
          isUploadingImage = false;
          _safeNotify();
        }
      } else {
        imageUrl = localPath;
      }

      final post = CommunityPost(
        id: '',
        userId: userId,
        body: composerText.trim(),
        author: _auth.currentUserName,
        imageUri: imageUrl,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await _firestore.addPost(post);
      composerText = '';
      selectedImageUri = null;
    } catch (e) {
      errorMessage = 'Failed to save post. Please try again.';
    }

    isPosting = false;
    isUploadingImage = false;
    _safeNotify();
  }

  /// Re-attempts a post that failed during image upload.
  /// Composer text and selected image are preserved from the previous attempt.
  Future<void> retryPost() async {
    uploadFailed = false;
    errorMessage = null;
    _safeNotify();
    await postUpdate();
  }

  Future<void> reportPost(String postId) async {
    errorMessage = 'Post reported. Thank you for keeping our community safe.';
    _safeNotify();
    await Future.delayed(const Duration(seconds: 3));
    clearError();
  }
}
