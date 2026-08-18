import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/utils/connectivity_service.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/domain/models/community_post.dart';
import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';
import 'package:cropguard_flutter/presentation/screens/community/community_provider.dart';

class _MockCommunityRepository extends Mock implements ICommunityRepository {}
class _MockAuthService extends Mock implements FirebaseAuthService {}
class _MockImageUploadService extends Mock implements ImageUploadService {}
class _MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late _MockCommunityRepository mockCommunityRepo;
  late _MockAuthService mockAuth;
  late _MockImageUploadService mockUploader;
  late _MockConnectivityService mockConnectivity;
  late CommunityProvider provider;

  setUp(() {
    mockCommunityRepo = _MockCommunityRepository();
    mockAuth = _MockAuthService();
    mockUploader = _MockImageUploadService();
    mockConnectivity = _MockConnectivityService();

    registerFallbackValue(PendingSyncType.communityPost);

    when(() => mockConnectivity.statusStream).thenAnswer((_) => Stream.value(ConnectionStatus.online));
    when(() => mockConnectivity.checkStatus()).thenAnswer((_) async => ConnectionStatus.online);
    when(() => mockConnectivity.checkIsOffline()).thenAnswer((_) async => false);
    when(() => mockCommunityRepo.getPostsStream()).thenAnswer((_) => Stream.value([]));
    when(() => mockCommunityRepo.getPendingSyncItems(any())).thenAnswer((_) async => []);
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
    );
  });

  tearDown(() {
    provider.dispose();
  });

  group('CommunityProvider - composer & post', () {
    test('postUpdate rejects empty content', () async {
      await provider.postUpdate('   ');
      expect(provider.errorMessage, 'Please write something before posting.');
    });

    test('postUpdate rejects anonymous users', () async {
      when(() => mockAuth.isAnonymous).thenReturn(true);
      await provider.postUpdate('Hello world');
      expect(provider.errorMessage, 'Guest users cannot post. Please sign in.');
    });

    test('successful postUpdate calls addPost and clears Composer state', () async {
      when(() => mockCommunityRepo.addPost(any())).thenAnswer((_) async => Result.success(null));

      await provider.postUpdate('New update from my farm!');

      verify(() => mockCommunityRepo.addPost(any())).called(1);
      expect(provider.selectedImageUri, isNull);
    });

    test('includes abandoned pending items in posts list with status abandoned', () async {
      final mockRepo = _MockCommunityRepository();
      when(() => mockConnectivity.statusStream).thenAnswer((_) => Stream.value(ConnectionStatus.online));
      when(() => mockConnectivity.checkStatus()).thenAnswer((_) async => ConnectionStatus.online);
      when(() => mockRepo.getPostsStream()).thenAnswer((_) => Stream.value([]));
      when(() => mockRepo.getPendingSyncItems(PendingSyncType.communityPost)).thenAnswer((_) async => [
        {
          'id': 42,
          'payload': '{"userId":"u123","body":"Failed post","author":"Kofi","timestamp":100000}',
          'status': 'abandoned',
        }
      ]);

      final p = CommunityProvider(mockRepo, mockAuth, mockUploader, mockConnectivity);
      await Future.delayed(const Duration(milliseconds: 50));

      final abandonedPost = p.posts.firstWhere((post) => post.id == 'pending_42');
      expect(abandonedPost.syncStatus, 'abandoned');
      expect(abandonedPost.body, 'Failed post');
      p.dispose();
    });
  });
}
