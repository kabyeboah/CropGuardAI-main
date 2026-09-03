import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cropguard_flutter/data/repositories/community_repository_impl.dart';
import 'package:cropguard_flutter/data/remote/supabase_database_service.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';
import 'package:cropguard_flutter/core/error/failures.dart';

class MockSupabaseDatabaseService extends Mock implements SupabaseDatabaseService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockImageUploadService extends Mock implements ImageUploadService {}

Future<Database> _openTestDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(PendingSyncQueue.createTableSql);
      },
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late MockSupabaseDatabaseService mockDatabaseService;
  late MockDatabaseHelper mockDbHelper;
  late MockImageUploadService mockImageUpload;
  late CommunityRepositoryImpl repo;
  late Database db;

  setUp(() async {
    db = await _openTestDb();
    mockDatabaseService = MockSupabaseDatabaseService();
    mockDbHelper = MockDatabaseHelper();
    mockImageUpload = MockImageUploadService();

    when(() => mockDbHelper.database).thenAnswer((_) async => db);

    repo =
        CommunityRepositoryImpl(mockDatabaseService, mockDbHelper, mockImageUpload);
  });

  tearDown(() async {
    await db.close();
  });

  group('CommunityRepositoryImpl.submitOutbreakReport', () {
    test('rejects unauthenticated report when userId is null or empty',
        () async {
      final resNull = await repo.submitOutbreakReport({
        'disease': 'Cassava Mosaic Disease',
      });
      expect(resNull.isError, true);
      expect(resNull.failure, isA<AuthFailure>());

      final resEmpty = await repo.submitOutbreakReport({
        'userId': '   ',
        'disease': 'Cassava Mosaic Disease',
      });
      expect(resEmpty.isError, true);
      expect(resEmpty.failure, isA<AuthFailure>());

      verifyNever(() => mockDatabaseService.submitOutbreakReport(any()));
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test('calls Firestore when authenticated and succeeds', () async {
      when(() => mockDatabaseService.submitOutbreakReport(any()))
          .thenAnswer((_) async {});

      final res = await repo.submitOutbreakReport({
        'userId': 'user123',
        'disease': 'Cassava Mosaic Disease',
      });

      expect(res.isSuccess, true);
      verify(() => mockDatabaseService.submitOutbreakReport(any())).called(1);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test(
        'queues payload in PendingSyncQueue when Firestore throws transient error',
        () async {
      when(() => mockDatabaseService.submitOutbreakReport(any()))
          .thenThrow(const ServerFailure('Network offline'));

      final res = await repo.submitOutbreakReport({
        'userId': 'user123',
        'disease': 'Cassava Mosaic Disease',
      });

      expect(res.isSuccess, true); // Optimistic success
      expect(await PendingSyncQueue.pendingCount(db), 1);
    });
  });

  group('CommunityRepositoryImpl.reportPost', () {
    test('rejects unauthenticated caller when reporterId is empty', () async {
      final res = await repo.reportPost(
        postId: 'post_123',
        reporterId: '',
        reason: 'spam',
      );

      expect(res.isError, true);
      expect(res.failure, isA<AuthFailure>());
      verifyNever(() => mockDatabaseService.reportPost(
            postId: any(named: 'postId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          ));
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test('calls FirestoreService.reportPost on valid report', () async {
      when(() => mockDatabaseService.reportPost(
            postId: any(named: 'postId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      final res = await repo.reportPost(
        postId: 'post_123',
        reporterId: 'user_456',
        reason: 'harmful_content',
      );

      expect(res.isSuccess, true);
      verify(() => mockDatabaseService.reportPost(
            postId: 'post_123',
            reporterId: 'user_456',
            reason: 'harmful_content',
          )).called(1);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test('queues reported post in PendingSyncQueue on transient error',
        () async {
      when(() => mockDatabaseService.reportPost(
            postId: any(named: 'postId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenThrow(const ServerFailure('Network offline'));

      final res = await repo.reportPost(
        postId: 'post_123',
        reporterId: 'user_456',
        reason: 'spam',
      );

      expect(res.isSuccess, true); // Optimistic success for the user
      expect(await PendingSyncQueue.pendingCount(db), 1);

      // Verify drainPendingSync handles PendingSyncType.reportedPost
      when(() => mockDatabaseService.reportPost(
            postId: any(named: 'postId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      await repo.drainPendingSync();
      expect(await PendingSyncQueue.pendingCount(db), 0);
      verify(() => mockDatabaseService.reportPost(
            postId: 'post_123',
            reporterId: 'user_456',
            reason: 'spam',
          )).called(2);
    });
  });
}
