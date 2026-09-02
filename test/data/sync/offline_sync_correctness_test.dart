import 'dart:io';

import 'package:cropguard_flutter/core/utils/streak_manager.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';
import 'package:cropguard_flutter/data/remote/supabase_database_service.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/data/repositories/community_repository_impl.dart';
import 'package:cropguard_flutter/data/repositories/detection_repository_impl.dart';
import 'package:cropguard_flutter/domain/models/community_post.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';
import 'package:cropguard_flutter/domain/repositories/i_classifier_repository.dart';
import 'package:cropguard_flutter/domain/usecases/scanner/scan_crop_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockClassifierRepository extends Mock implements IClassifierRepository {}

class MockSupabaseDatabaseService extends Mock implements SupabaseDatabaseService {}

class MockImageUploadService extends Mock implements ImageUploadService {}

class MockStreakManager extends Mock implements StreakManager {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(CommunityPost(
      id: 'fallback_id',
      userId: 'fallback_user',
      body: 'fallback_content',
      author: 'fallback_author',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  });

  late Directory tempDir;
  late String dbPath;
  late DatabaseHelper dbHelper;
  late MockClassifierRepository mockClassifier;
  late MockSupabaseDatabaseService mockDatabaseService;
  late MockImageUploadService mockImageUpload;
  late MockStreakManager mockStreakManager;
  late DetectionRepositoryImpl detectionRepo;
  late CommunityRepositoryImpl communityRepo;
  int testCounter = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cg_offline_sync_test_');
    testCounter++;
    dbPath = p.join(tempDir.path, 'offline_sync_$testCounter.db');
    dbHelper = DatabaseHelper.forTest(dbPath);
    mockClassifier = MockClassifierRepository();
    mockDatabaseService = MockSupabaseDatabaseService();
    mockImageUpload = MockImageUploadService();
    mockStreakManager = MockStreakManager();
    detectionRepo = DetectionRepositoryImpl(dbHelper);
    communityRepo = CommunityRepositoryImpl(
      mockDatabaseService,
      dbHelper,
      mockImageUpload,
    );
    PendingSyncQueue.resetDraining();
  });

  tearDown(() async {
    await dbHelper.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  DetectionResult createDetection({
    int id = 0,
    String userId = 'farmer_1',
    String diseaseLabel = 'tomato_early_blight',
    String cropType = 'tomato',
    bool isHealthy = false,
    bool isSynced = false,
    int? syncedAt,
  }) {
    return DetectionResult(
      id: id,
      userId: userId,
      imagePath: '/data/crops/sample.jpg',
      diseaseLabel: diseaseLabel,
      displayName: 'Early Blight',
      confidence: 0.94,
      severity: 'medium',
      isHealthy: isHealthy,
      cropType: cropType,
      cause: 'Alternaria solani',
      treatments: const ['Apply copper spray', 'Remove infected lower leaves'],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDegraded: false,
      modelVersion: 'v2.4.0',
      isSynced: isSynced,
      syncedAt: syncedAt,
    );
  }

  group('Offline-First Correctness and Synchronization', () {
    test(
        'Offline scan and save: stores detection locally with isSynced=0 and queues pending sync upload',
        () async {
      when(() => mockDatabaseService.upsertScan(any(), any()))
          .thenThrow(const SocketException('No route to host (offline)'));
      when(() => mockStreakManager.recordScan()).thenAnswer((_) async => 1);

      final useCase = ScanCropUseCase(
        mockClassifier,
        detectionRepo,
        mockStreakManager,
        communityRepo,
      );

      final saveResult = await useCase.saveResolvedScan(
        userId: 'farmer_1',
        imagePath: '/crops/tomato_1.jpg',
        diseaseLabel: 'tomato_early_blight',
        confidence: 0.95,
        isDegraded: false,
        topCandidates: const [],
      );

      expect(saveResult.isSuccess, isTrue);
      final savedDetection = saveResult.data!;
      expect(savedDetection.id, isNotNull);

      // Verify stored in SQLite as unsynced
      final dbDetection = await dbHelper.getDetectionById(savedDetection.id);
      expect(dbDetection, isNotNull);
      expect(dbDetection!.isSynced, isFalse);
      expect(dbDetection.syncedAt, isNull);
      expect(dbDetection.userId, 'farmer_1');

      // Verify queued in pending_sync table
      final db = await dbHelper.database;
      final pendingCount = await PendingSyncQueue.pendingCount(db);
      expect(pendingCount, 1);

      final pendingItems = await PendingSyncQueue.getPendingItems(db,
          type: PendingSyncType.scanUpload);
      expect(pendingItems.length, 1);
      expect(pendingItems.first['payload'],
          contains(savedDetection.id.toString()));
    });

    test(
        'Network disappears and returns: drains pending queue, replays writes, and marks local scan synced',
        () async {
      final db = await dbHelper.database;

      // 1. Save 2 detections locally while network is down
      final det1 = createDetection(userId: 'farmer_alice');
      final det2 = createDetection(
          userId: 'farmer_alice', diseaseLabel: 'cassava_mosaic');
      final id1 = await dbHelper.insertDetection(det1);
      final id2 = await dbHelper.insertDetection(det2);

      // Cloud writes fail -> enqueued into pending sync
      when(() => mockDatabaseService.upsertScan(any(), any()))
          .thenThrow(const SocketException('Network is down'));

      await communityRepo.upsertScan(
          id1.toString(), det1.copyWith(id: id1).toMap());
      await communityRepo.upsertScan(
          id2.toString(), det2.copyWith(id: id2).toMap());

      expect(await PendingSyncQueue.pendingCount(db), 2);
      expect(
          (await dbHelper.getUnsyncedDetections(userId: 'farmer_alice')).length,
          2);

      // 2. Network returns: mockDatabaseService now succeeds
      final uploadedDocs = <String, Map<String, dynamic>>{};
      when(() => mockDatabaseService.upsertScan(any(), any()))
          .thenAnswer((inv) async {
        final docId = inv.positionalArguments[0] as String;
        final data = inv.positionalArguments[1] as Map<String, dynamic>;
        uploadedDocs[docId] = data;
      });

      // 3. Drain pending sync queue
      await communityRepo.drainPendingSync();

      // 4. Verify no remaining pending items
      expect(await PendingSyncQueue.pendingCount(db), 0);
      expect(uploadedDocs.containsKey(id1.toString()), isTrue);
      expect(uploadedDocs.containsKey(id2.toString()), isTrue);

      // 5. Verify local SQLite records are now marked synced
      final unsyncedAfter =
          await dbHelper.getUnsyncedDetections(userId: 'farmer_alice');
      expect(unsyncedAfter, isEmpty);

      final updated1 = await dbHelper.getDetectionById(id1);
      final updated2 = await dbHelper.getDetectionById(id2);
      expect(updated1!.isSynced, isTrue);
      expect(updated1.syncedAt, isNotNull);
      expect(updated2!.isSynced, isTrue);
      expect(updated2.syncedAt, isNotNull);
    });

    test(
        'Ordering (FIFO): operations are drained in strict chronological sequence',
        () async {
      final db = await dbHelper.database;
      final executionOrder = <String>[];

      // Enqueue 4 different operations with millisecond delays to guarantee monotonic timestamps
      await PendingSyncQueue.enqueue(db,
          type: PendingSyncType.communityPost, payload: {'order': 'first'});
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await PendingSyncQueue.enqueue(db,
          type: PendingSyncType.outbreakReport, payload: {'order': 'second'});
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await PendingSyncQueue.enqueue(db,
          type: PendingSyncType.scanUpload, payload: {'order': 'third'});
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await PendingSyncQueue.enqueue(db,
          type: PendingSyncType.treatmentAdd, payload: {'order': 'fourth'});

      await PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        executionOrder.add(payload['order'] as String);
        return true;
      });

      expect(executionOrder, ['first', 'second', 'third', 'fourth']);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test(
        'Retry and backoff: increments retry count, updates status to failed, and transitions to abandoned after maxRetries',
        () async {
      final db = await dbHelper.database;

      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.feedbackCorrection,
        payload: {'userId': 'u1', 'detectionId': 100},
      );

      // Attempt 1: failure -> retry_count becomes 1, status = failed
      await PendingSyncQueue.drain(db,
          handler: (id, type, payload) async => false);
      var rows = await db.query('pending_sync');
      expect(rows.first['retry_count'], 1);
      expect(rows.first['status'], 'failed');
      expect(await PendingSyncQueue.pendingCount(db), 1);

      // Attempts 2, 3, 4: failure -> retry_count reaches 4
      for (int i = 2; i <= 4; i++) {
        await PendingSyncQueue.drain(db,
            handler: (id, type, payload) async => false);
        rows = await db.query('pending_sync');
        expect(rows.first['retry_count'], i);
        expect(rows.first['status'], 'failed');
      }

      // Attempt 5: maxRetries (5) reached -> status becomes abandoned
      await PendingSyncQueue.drain(db,
          handler: (id, type, payload) async => false);
      rows = await db.query('pending_sync');
      expect(rows.first['retry_count'], 5);
      expect(rows.first['status'], 'abandoned');

      // Abandoned items are excluded from pendingCount to avoid inflating UI badge
      expect(await PendingSyncQueue.pendingCount(db), 0);

      // Subsequent drains do not process abandoned items
      bool handlerInvoked = false;
      await PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        handlerInvoked = true;
        return true;
      });
      expect(handlerInvoked, isFalse);
    });

    test(
        'App restart simulation: preserves un-synced scans and pending queue across DB close & re-open',
        () async {
      final db = await dbHelper.database;

      // 1. Seed scan & pending items
      final detId =
          await dbHelper.insertDetection(createDetection(userId: 'farmer_bob'));
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.scanUpload,
        payload: {'id': detId, 'userId': 'farmer_bob', 'disease': 'rust'},
      );
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.treatmentAdd,
        payload: {
          'id': 'treatment_bob_1',
          'userId': 'farmer_bob',
          'step': 'Irrigate'
        },
      );

      expect(await PendingSyncQueue.pendingCount(db), 2);
      expect(
          (await dbHelper.getUnsyncedDetections(userId: 'farmer_bob')).length,
          1);

      // 2. Simulate app termination by closing the database
      await dbHelper.close();

      // 3. Simulate app restart: instantiate a new DatabaseHelper for the same file path
      final restartedHelper = DatabaseHelper.forTest(dbPath);
      final restartedDb = await restartedHelper.database;

      // Verify no records lost or corrupted
      expect(await PendingSyncQueue.pendingCount(restartedDb), 2);
      final pendingScans = await PendingSyncQueue.getPendingItems(restartedDb,
          type: PendingSyncType.scanUpload);
      expect(pendingScans.length, 1);
      expect(pendingScans.first['payload'], contains('farmer_bob'));

      final unsynced =
          await restartedHelper.getUnsyncedDetections(userId: 'farmer_bob');
      expect(unsynced.length, 1);
      expect(unsynced.first.id, detId);

      // 4. Drain successfully post-restart
      final replayedTypes = <PendingSyncType>[];
      await PendingSyncQueue.drain(restartedDb,
          handler: (id, type, payload) async {
        replayedTypes.add(type);
        if (type == PendingSyncType.scanUpload) {
          await restartedHelper.markDetectionSynced(detId);
        }
        return true;
      });

      expect(replayedTypes,
          [PendingSyncType.scanUpload, PendingSyncType.treatmentAdd]);
      expect(await PendingSyncQueue.pendingCount(restartedDb), 0);
      expect(await restartedHelper.getUnsyncedDetections(userId: 'farmer_bob'),
          isEmpty);

      await restartedHelper.close();
    });

    test(
        'Idempotency & Deduplication: duplicate/replayed upserts do not duplicate records',
        () async {
      final uploadedDocs = <String, Map<String, dynamic>>{};
      when(() => mockDatabaseService.upsertScan(any(), any()))
          .thenAnswer((inv) async {
        final docId = inv.positionalArguments[0] as String;
        final data = inv.positionalArguments[1] as Map<String, dynamic>;
        uploadedDocs[docId] = data;
      });

      final scanData = {'id': 'scan_99', 'disease': 'blight', 'v': 1};

      // First upload
      await communityRepo.upsertScan('scan_99', scanData);
      expect(uploadedDocs.length, 1);
      expect(uploadedDocs['scan_99']!['v'], 1);

      // Second upload with updated version (idempotent overwrite/merge)
      await communityRepo.upsertScan(
          'scan_99', {'id': 'scan_99', 'disease': 'blight', 'v': 2});
      expect(uploadedDocs.length,
          1); // Still 1 document in remote map (no duplicate doc created)
      expect(uploadedDocs['scan_99']!['v'], 2);
    });

    test(
        'In-place payload update avoids re-uploading image on network failure during post submission',
        () async {
      final db = await dbHelper.database;

      // 1. Enqueue a community post with local image
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.communityPost,
        payload: {
          'title': 'Leaf spot issue',
          'body': 'Need diagnosis help',
          'author': 'Kwame',
          'userId': 'user_123',
          'tag': 'Maize',
          'imageUri': '/local/storage/leaf.jpg',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      int uploadCalls = 0;
      when(() => mockImageUpload.uploadImage('/local/storage/leaf.jpg',
          userId: 'user_123')).thenAnswer((_) async {
        uploadCalls++;
        return 'https://cloudinary.com/crops/leaf_cdn.jpg';
      });

      // Mock Firestore failure on first drain attempt after image is uploaded
      when(() => mockDatabaseService.addPost(any()))
          .thenThrow(const SocketException('Firestore unavailable'));

      // First drain attempt
      await communityRepo.drainPendingSync();

      expect(uploadCalls, 1);
      // Verify SQLite queue payload was updated in-place with remote URL
      final rows = await db.query('pending_sync');
      expect(rows.length, 1);
      expect(rows.first['payload'],
          contains('https://cloudinary.com/crops/leaf_cdn.jpg'));
      expect(rows.first['status'], 'failed');

      // Second drain attempt: Firestore now succeeds
      when(() => mockDatabaseService.addPost(any())).thenAnswer((_) async {});
      await communityRepo.drainPendingSync();

      // Verify upload was NOT called again (deduped/idempotent)
      expect(uploadCalls, 1);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test(
        'Conflict handling: replace conflict algorithm and transaction safety prevent constraint errors',
        () async {
      // 1. Insert treatment plan with explicit ID
      final t1 = TreatmentPlan(
        id: 'tp_001',
        userId: 'farmer_1',
        detectionId: 1,
        cropType: 'maize',
        diseaseName: 'rust',
        step: 'Initial step',
        completed: false,
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await dbHelper.insertTreatment(t1);

      // 2. Re-insert treatment plan with same ID and toggled completion
      final t2 = t1.copyWith(completed: true);
      await dbHelper.insertTreatment(t2);

      final allTreatments = await dbHelper.getAllTreatments(userId: 'farmer_1');
      expect(allTreatments.length, 1);
      expect(allTreatments.first.completed, isTrue);

      // 3. User account re-assignment transaction (guest upgrade)
      await dbHelper.insertDetection(createDetection(userId: 'guest_user'));
      await dbHelper.reassignUserData('guest_user', 'registered_user');

      final guestDetections =
          await dbHelper.getAllDetections(userId: 'guest_user');
      final registeredDetections =
          await dbHelper.getAllDetections(userId: 'registered_user');
      expect(guestDetections, isEmpty);
      expect(registeredDetections.length, 1);
      expect(registeredDetections.first.isSynced,
          isFalse); // Reset to unsynced for registered user
    });
  });
}
