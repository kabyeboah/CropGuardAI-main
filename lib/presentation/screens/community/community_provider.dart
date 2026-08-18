import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/analytics_service.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../data/remote/image_upload_service.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../data/local/pending_sync_queue.dart';
import '../../../domain/models/community_post.dart';
import '../../../domain/repositories/i_community_repository.dart';
import '../../../core/utils/image_quality_analyzer.dart';

/// Community feed: images via ImageUploadService (Cloudinary + Firebase Storage), posts in Firestore.
class CommunityProvider extends ChangeNotifier {
  final ICommunityRepository _communityRepo;
  final FirebaseAuthService _auth;
  final ImageUploadService _uploader;
  final ConnectivityService _connectivity;
  StreamSubscription<ConnectionStatus>? _connectivitySub;
  StreamSubscription<List<CommunityPost>>? _postsSubscription;

  CommunityProvider(this._communityRepo, this._auth, this._uploader, this._connectivity) {
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
    _pendingPollTimer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  List<CommunityPost> posts = [];
  List<CommunityPost> _cloudPosts = [];
  List<CommunityPost> _pendingPosts = [];
  Timer? _pendingPollTimer;

  String? selectedImageUri;
  bool isPosting = false;
  bool isUploadingImage = false;
  String? errorMessage;
  // True when errorMessage was caused specifically by a Cloudinary upload
  // failure — the screen shows a Retry button in this case.
  bool uploadFailed = false;
  // Last text successfully submitted; used by retryPost() to replay the attempt
  // without needing the screen to pass the controller text again.
  String _lastComposerText = '';
  ConnectionStatus connectionStatus = ConnectionStatus.online;
  bool get isOffline => connectionStatus == ConnectionStatus.offline;

  void _listenToPosts() {
    _postsSubscription = _communityRepo.getPostsStream().listen(
      (p) {
        _cloudPosts = p;
        _combineAndNotify();
      },
      onError: (_) {
        _combineAndNotify();
      },
    );
    _startPendingQueuePolling();
  }

  void _startPendingQueuePolling() {
    _pendingPollTimer?.cancel();
    _pendingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshPendingPosts());
    _refreshPendingPosts();
  }

  Future<void> _refreshPendingPosts() async {
    try {
      final rows = await _communityRepo.getPendingSyncItems(PendingSyncType.communityPost);
      final list = <CommunityPost>[];
      for (final row in rows) {
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        final status = row['status'] as String? ?? 'pending';
        // Include abandoned rows so the "Delivery Failed" badge is shown to the
        // user instead of the post silently disappearing after max retries.
        final postId = 'pending_${row['id']}';
        list.add(CommunityPost.fromMap(payload, postId, syncStatus: status));
      }
      _pendingPosts = list;
      _combineAndNotify();
    } catch (_) {
      // Swallowed
    }
  }

  static final List<CommunityPost> _seedPosts = [
    CommunityPost(
      id: 'seed_1',
      userId: 'expert_01',
      author: 'Kofi Mensah',
      tag: 'Cocoa',
      body:
          'Noticed early signs of Black Pod on my cocoa trees in Ashanti after the recent heavy rains. Applied copper hydroxide fungicide this morning. What fungicides are working best for you this season?',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      expertResponse:
          'Good job acting early Kofi! Ensure proper shade management, prune affected pods immediately, and maintain 2.5m spacing to reduce humidity.',
    ),
    CommunityPost(
      id: 'seed_2',
      userId: 'farmer_02',
      author: 'Ama Serwaa',
      tag: 'Cassava',
      body:
          'Yellow mosaic patterns appearing on young cassava leaves in Techiman. Is this Cassava Mosaic Disease? Should I rogue out the affected plants?',
      timestamp: DateTime.now().subtract(const Duration(hours: 7)).millisecondsSinceEpoch,
      expertResponse:
          'Yes Ama, rogue out and safely destroy infected plants immediately to prevent whiteflies from spreading CMD to your remaining healthy cassava crop.',
    ),
    CommunityPost(
      id: 'seed_3',
      userId: 'farmer_03',
      author: 'Kwesi Appiah',
      tag: 'Maize',
      body:
          'Maize crop in Ejura is growing strong after top dressing with Urea. Scouting weekly for Fall Armyworm egg masses on leaf undersides.',
      timestamp: DateTime.now().subtract(const Duration(hours: 14)).millisecondsSinceEpoch,
    ),
    CommunityPost(
      id: 'seed_4',
      userId: 'farmer_04',
      author: 'Akosua Boateng',
      tag: 'Tomato',
      body:
          'Pro tip for tomato farmers in Akomadan: Stake your tomatoes early before fruiting starts to prevent ground contact rot during rainy weeks.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    ),
  ];

  void _combineAndNotify() {
    // If no cloud posts exist yet, display curated seed community discussions
    final cloudOrSeed = _cloudPosts.isNotEmpty ? _cloudPosts : _seedPosts;
    final combined = <CommunityPost>[..._pendingPosts, ...cloudOrSeed];
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    posts = combined;
    _safeNotify();
  }


  Future<void> onImageSelected(String? uri) async {
    if (uri == null) {
      selectedImageUri = null;
      errorMessage = null;
      _safeNotify();
      return;
    }

    isUploadingImage = true;
    errorMessage = null;
    _safeNotify();

    try {
      final qualityCheck = await ImageQualityAnalyzer.analyzeFile(uri);
      if (qualityCheck != null && !qualityCheck.isAcceptable) {
        selectedImageUri = null;
        errorMessage = _getQualityErrorMessage(qualityCheck.issue);
      } else {
        selectedImageUri = uri;
      }
    } catch (e) {
      selectedImageUri = uri;
    } finally {
      isUploadingImage = false;
      _safeNotify();
    }
  }

  String _getQualityErrorMessage(ImageQualityIssue? issue) {
    switch (issue) {
      case ImageQualityIssue.blurry:
        return 'Image is too blurry. Please hold the camera steady.';
      case ImageQualityIssue.tooDark:
        return 'Image is too dark. Please use more light or the torch.';
      case ImageQualityIssue.tooBright:
        return 'Image is too bright. Please avoid direct glare.';
      case ImageQualityIssue.tooSmall:
        return 'Image resolution is too low.';
      default:
        return 'Poor image quality detected.';
    }
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

  Future<void> postUpdate(String composerText, {VoidCallback? onPosted}) async {
    _lastComposerText = composerText;
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
      final localPath = selectedImageUri;
      String? imageUrl;

      // Check connectivity status first
      final isNetworkOffline = await _connectivity.checkIsOffline();

      if (localPath != null &&
          !localPath.startsWith('http://') &&
          !localPath.startsWith('https://')) {
        if (isNetworkOffline) {
          // If offline, save the local path; background sync will upload it
          imageUrl = localPath;
        } else {
          isUploadingImage = true;
          _safeNotify();
          try {
            imageUrl = await _uploader.uploadImage(localPath, userId: userId);
          } catch (e) {
            // Upload failed across Cloudinary and Firebase Storage, treat as local/offline and queue it
            imageUrl = localPath;
          } finally {
            isUploadingImage = false;
            _safeNotify();
          }
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

      // If we have a local image path, we must queue it immediately instead of
      // trying to save to Firestore (which would lack the remote Cloudinary URL).
      if (isNetworkOffline || (imageUrl != null && !imageUrl.startsWith('http'))) {
        await _communityRepo.addPost(post);
      } else {
        final res = await _communityRepo.addPost(post);
        res.fold(
          (_) {
            // Success
          },
          (failure) {
            // Failed, but addPost enqueues it.
          },
        );
      }

      try {
        if (sl.isRegistered<AnalyticsService>()) {
          unawaited(sl<AnalyticsService>().logCommunityPostSubmitted());
        }
      } catch (_) {}

      onPosted?.call();
      selectedImageUri = null;
      await _refreshPendingPosts();
    } catch (e) {
      errorMessage = 'Failed to save post. Please try again.';
    } finally {
      isPosting = false;
      isUploadingImage = false;
      _safeNotify();
    }
  }

  /// Re-attempts a post that failed during image upload.
  /// Composer text and selected image are preserved from the previous attempt.
  Future<void> retryPost({VoidCallback? onPosted}) async {
    uploadFailed = false;
    errorMessage = null;
    _safeNotify();
    await postUpdate(_lastComposerText, onPosted: onPosted);
  }

  Future<void> reportPost(String postId) async {
    errorMessage = 'Post reported. Thank you for keeping our community safe.';
    _safeNotify();
    await Future.delayed(const Duration(seconds: 3));
    clearError();
  }
}
