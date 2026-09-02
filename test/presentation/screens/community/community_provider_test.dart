import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/utils/connectivity_service.dart';
import 'package:cropguard_flutter/core/utils/rate_limiter.dart';
import 'package:cropguard_flutter/core/utils/user_block_service.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/data/remote/supabase_auth_service.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/domain/models/community_post.dart';
import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';
import 'package:cropguard_flutter/presentation/screens/community/community_provider.dart';

class _MockCommunityRepository extends Mock implements ICommunityRepository {}

class _MockAuthService extends Mock implements SupabaseAuthService {}

class _MockImageUploadService extends Mock implements ImageUploadService {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late _MockCommunityRepository mockCommunityRepo;
  late _MockAuthService mockAuth;
  late _MockImageUploadService mockUploader;
  late _MockConnectivityService mockConnectivity;
  late UserBlockService blockService;
  late RateLimiter rateLimiter;
  late CommunityProvider provider;

  setUp(() {
    mockCommunityRepo = _MockCommunityRepository();
    mockAuth = _MockAuthService();
    mockUploader = _MockImageUploadService();
    mockConnectivity = _MockConnectivityService();
    blockService = UserBlockService();
    rateLimiter = RateLimiter();

    registerFallbackValue(PendingSyncType.communityPost);

    when(() => mockConnectivity.statusStream)
        .thenAnswer((_) => Stream.value(ConnectionStatus.online));
    when(() => mockConnectivity.checkStatus())
        .thenAnswer((_) async => ConnectionStatus.online);
    when(() => mockConnectivity.checkIsOffline())
        .thenAnswer((_) async => false);
    when(() => mockCommunityRepo.getPostsStream())
        .thenAnswer((_) => Stream.value([]));
    when(() => mockCommunityRepo.getPendingSyncItems(any()))
        .thenAnswer((_) async => []);
    when(() => mockAuth.isAnonymous).thenReturn(false);
    when(() => mockAuth.currentUserId).thenReturn('u123');
    when(() => mockAuth.currentUserName).thenReturn('Farmer Kofi');

    registerFallbackValue(
      const CommunityPost(
        id: '',
        userId: 'u123',
        body: 'body',
        author: 'Farmer Kofi',
        timestamp: 0,
      ),
    );

    provider = CommunityProvider(
      mockCommunityRepo,
      mockAuth,
      mockUploader,
      mockConnectivity,
      blockService: blockService,
      rateLimiter: rateLimiter,
    );
  });

  tearDown(() {
    provider.dispose();
  });

  group('CommunityProvider - composer & post', () {
    test('postUpdate rejects empty content', () async {
      await provider.postUpdate('   ');
      expect(provider.errorMessage, 'Post content cannot be empty.');
    });

    test('postUpdate rejects anonymous users', () async {
      when(() => mockAuth.isAnonymous).thenReturn(true);
      await provider.postUpdate('Hello world');
      expect(provider.errorMessage, 'Guest users cannot post. Please sign in.');
    });

    test('postUpdate rejects spam and external links', () async {
      when(() => mockCommunityRepo.addPost(any()))
          .thenAnswer((_) async => Result.success(null));

      await provider.postUpdate('Check out my scam link https://badsite.com');
      expect(provider.errorMessage, contains('External links'));
      verifyNever(() => mockCommunityRepo.addPost(any()));
    });

    test('postUpdate rejects abusive language', () async {
      await provider.postUpdate('You are an idiot and this is stupid');
      expect(provider.errorMessage, contains('offensive or abusive'));
      verifyNever(() => mockCommunityRepo.addPost(any()));
    });

    test(
        'successful postUpdate calls addPost and enforces 30s cooldown rate limit',
        () async {
      when(() => mockCommunityRepo.addPost(any()))
          .thenAnswer((_) async => Result.success(null));

      await provider.postUpdate('New update from my farm!');
      verify(() => mockCommunityRepo.addPost(any())).called(1);
      expect(provider.selectedImageUri, isNull);

      // Immediate second post attempt triggers rate limiter
      await provider.postUpdate('Another different update!');
      expect(provider.errorMessage, contains('Please wait'));
    });

    test('includes abandoned pending items in posts list with status abandoned',
        () async {
      final mockRepo = _MockCommunityRepository();
      when(() => mockConnectivity.statusStream)
          .thenAnswer((_) => Stream.value(ConnectionStatus.online));
      when(() => mockConnectivity.checkStatus())
          .thenAnswer((_) async => ConnectionStatus.online);
      when(() => mockRepo.getPostsStream()).thenAnswer((_) => Stream.value([]));
      when(() => mockRepo.getPendingSyncItems(PendingSyncType.communityPost))
          .thenAnswer((_) async => [
                {
                  'id': 42,
                  'payload':
                      '{"userId":"u123","body":"Failed post","author":"Kofi","timestamp":100000}',
                  'status': 'abandoned',
                }
              ]);

      final p = CommunityProvider(
          mockRepo, mockAuth, mockUploader, mockConnectivity,
          blockService: blockService, rateLimiter: rateLimiter);
      await Future.delayed(const Duration(milliseconds: 50));

      final abandonedPost =
          p.posts.firstWhere((post) => post.id == 'pending_42');
      expect(abandonedPost.syncStatus, 'abandoned');
      expect(abandonedPost.body, 'Failed post');
      p.dispose();
    });
  });

  group('CommunityProvider - User Blocking', () {
    test('blocking a user excludes their posts from the feed immediately',
        () async {
      final mockRepo = _MockCommunityRepository();
      when(() => mockConnectivity.statusStream)
          .thenAnswer((_) => Stream.value(ConnectionStatus.online));
      when(() => mockConnectivity.checkStatus())
          .thenAnswer((_) async => ConnectionStatus.online);
      when(() => mockRepo.getPendingSyncItems(any()))
          .thenAnswer((_) async => []);

      final testPosts = [
        const CommunityPost(
          id: 'p1',
          userId: 'abusive_user',
          body: 'Bad content',
          author: 'Troll',
          timestamp: 1000,
        ),
        const CommunityPost(
          id: 'p2',
          userId: 'good_farmer',
          body: 'Good harvest today',
          author: 'Kofi',
          timestamp: 2000,
        ),
      ];

      when(() => mockRepo.getPostsStream())
          .thenAnswer((_) => Stream.value(testPosts));

      final p = CommunityProvider(
          mockRepo, mockAuth, mockUploader, mockConnectivity,
          blockService: blockService, rateLimiter: rateLimiter);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(p.posts.length, 2);

      // Block abusive_user
      await p.blockUser('abusive_user');

      expect(p.posts.length, 1);
      expect(p.posts.first.userId, 'good_farmer');
      p.dispose();
    });
  });

  group('CommunityProvider - reportPost', () {
    test('reportPost rejects anonymous/guest users', () async {
      when(() => mockAuth.isAnonymous).thenReturn(true);

      await provider.reportPost('post_123');

      expect(provider.errorMessage, 'Please sign in to report posts.');
      verifyNever(() => mockCommunityRepo.reportPost(
            postId: any(named: 'postId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          ));
    });

    test(
        'reportPost calls repository with user ID and hides reported post locally',
        () async {
      when(() => mockCommunityRepo.reportPost(
            postId: any(named: 'postId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => Result.success(null));

      await provider.reportPost('seed_1',
          reason: 'Spam advertising', category: 'Spam');

      verify(() => mockCommunityRepo.reportPost(
            postId: 'seed_1',
            reporterId: 'u123',
            reason: '[Spam] Spam advertising',
          )).called(1);
      expect(provider.errorMessage,
          'Post reported. Thank you for keeping our community safe.');

      // Verify reported post is hidden from feed
      expect(provider.posts.any((p) => p.id == 'seed_1'), isFalse);
    });
  });
}
