import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';

/// Opens an in-memory SQLite database with the pending_sync table created.
Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(PendingSyncQueue.createTableSql);
      },
    ),
  );
  return db;
}

void main() {
  group('PendingSyncQueue', () {
    late Database db;

    setUp(() async {
      db = await _openTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('pendingCount is 0 on empty queue', () async {
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test('enqueue increments pending count', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.communityPost,
        payload: {'text': 'hello'},
      );
      expect(await PendingSyncQueue.pendingCount(db), 1);
    });

    test('enqueue stores correct type and payload', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.outbreakReport,
        payload: {'disease': 'blight', 'severity': 'high'},
      );
      final items = await PendingSyncQueue.getPendingItems(
        db,
        type: PendingSyncType.outbreakReport,
      );
      expect(items.length, 1);
      expect(items.first['type'], 'outbreakReport');
    });

    test('drain calls handler for each item and removes on success', () async {
      for (int i = 0; i < 3; i++) {
        await PendingSyncQueue.enqueue(
          db,
          type: PendingSyncType.communityPost,
          payload: {'index': i},
        );
      }
      final handledIds = <int>[];
      await PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        handledIds.add(id);
        return true; // success → remove
      });
      expect(handledIds.length, 3);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test('drain keeps item when handler returns false', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.feedbackCorrection,
        payload: {'id': '123'},
      );
      await PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        return false; // failure → keep
      });
      expect(await PendingSyncQueue.pendingCount(db), 1);
    });

    test('drain items are ordered by creation time (FIFO)', () async {
      for (int i = 0; i < 5; i++) {
        await PendingSyncQueue.enqueue(
          db,
          type: PendingSyncType.communityPost,
          payload: {'order': i},
        );
        // Tiny delay to guarantee distinct timestamps
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final order = <int>[];
      await PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        order.add(payload['order'] as int);
        return true;
      });
      expect(order, [0, 1, 2, 3, 4]);
    });

    test('concurrent drain guard prevents double-drain', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.communityPost,
        payload: {'x': 1},
      );
      int handledCount = 0;
      // Launch two drains simultaneously — only one should execute
      final f1 = PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        handledCount++;
        return true;
      });
      final f2 = PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        handledCount++;
        return true;
      });
      await Future.wait([f1, f2]);
      expect(handledCount, 1);
    });

    test('clear removes all items when called without arguments', () async {
      for (int i = 0; i < 4; i++) {
        await PendingSyncQueue.enqueue(
          db,
          type: PendingSyncType.communityPost,
          payload: {'i': i},
        );
      }
      await PendingSyncQueue.clear(db);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test(
        'clear with abandonedOnly true only removes abandoned items, preserving in-flight scans',
        () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.scanUpload,
        payload: {'id': 'scan_1'},
      );
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.communityPost,
        payload: {'id': 'post_1'},
      );
      // Mark one item as abandoned
      await db.update('pending_sync', {'status': 'abandoned'},
          where: 'id = ?', whereArgs: [1]);

      expect(await PendingSyncQueue.pendingCount(db), 1);
      final allRowsBefore = await db.query('pending_sync');
      expect(allRowsBefore.length, 2);

      await PendingSyncQueue.clear(db, abandonedOnly: true);

      final allRowsAfter = await db.query('pending_sync');
      expect(allRowsAfter.length, 1);
      expect(allRowsAfter.first['id'], 2);
      expect(await PendingSyncQueue.pendingCount(db), 1);
    });

    test('clear with userId scopes removal to specific user', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.scanUpload,
        payload: {'userId': 'user_a', 'data': 'scan_a'},
      );
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.scanUpload,
        payload: {'userId': 'user_b', 'data': 'scan_b'},
      );

      expect(await PendingSyncQueue.pendingCount(db), 2);

      await PendingSyncQueue.clear(db, userId: 'user_a');

      final remaining = await db.query('pending_sync');
      expect(remaining.length, 1);
      expect(remaining.first['payload'], contains('user_b'));
      expect(await PendingSyncQueue.pendingCount(db), 1);
    });

    test('drainWithTimeout executes drain and handles timeout gracefully',
        () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.communityPost,
        payload: {'title': 'Offline Post'},
      );

      bool drained = false;
      await PendingSyncQueue.drainWithTimeout(
        db,
        handler: (id, type, payload) async {
          drained = true;
          return true;
        },
        timeout: const Duration(seconds: 2),
      );

      expect(drained, isTrue);
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });

    test('getPendingItems filters by type', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.communityPost,
        payload: {},
      );
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.outbreakReport,
        payload: {},
      );
      final posts = await PendingSyncQueue.getPendingItems(
        db,
        type: PendingSyncType.communityPost,
      );
      expect(posts.length, 1);
      expect(posts.first['type'], 'communityPost');
    });

    test('updatePayload modifies stored payload', () async {
      await PendingSyncQueue.enqueue(
        db,
        type: PendingSyncType.expertRequest,
        payload: {'v': 1},
      );
      final rows = await db.query('pending_sync');
      final id = rows.first['id'] as int;
      await PendingSyncQueue.updatePayload(db, id, {'v': 99});
      final updated =
          await db.query('pending_sync', where: 'id = ?', whereArgs: [id]);
      expect(updated.first['payload'], contains('99'));
    });

    test(
        'sanitizePayload converts non-JSON encodable values (DateTime, sentinels, nested objects) to primitive strings',
        () {
      final now = DateTime.now();
      final sanitized = PendingSyncQueue.sanitizePayload({
        'string': 'abc',
        'number': 123,
        'boolean': true,
        'date': now,
        'nestedMap': {
          'innerDate': now,
        },
        'list': [now, 'text'],
      });

      expect(sanitized['string'], 'abc');
      expect(sanitized['number'], 123);
      expect(sanitized['boolean'], true);
      expect(sanitized['date'], now.toIso8601String());
      expect(sanitized['nestedMap']['innerDate'], now.toIso8601String());
      expect(sanitized['list'], [now.toIso8601String(), 'text']);
    });

    test(
        'drain marks unrecognized operation types as abandoned without invoking handler',
        () async {
      // Insert a row with an unknown/obsolete type directly into the table
      await db.insert('pending_sync', {
        'type': 'legacyDeprecatedType_v1',
        'payload': '{"someKey": "someValue"}',
        'status': 'pending',
        'retry_count': 0,
        'created': DateTime.now().millisecondsSinceEpoch,
      });

      expect(await PendingSyncQueue.pendingCount(db), 1);

      final handledTypes = <PendingSyncType>[];
      await PendingSyncQueue.drain(db, handler: (id, type, payload) async {
        handledTypes.add(type);
        return true;
      });

      // Handler should never be invoked for unrecognized types
      expect(handledTypes, isEmpty);

      // Row status should be updated to abandoned in the database
      final rows = await db.query('pending_sync');
      expect(rows.length, 1);
      expect(rows.first['status'], 'abandoned');

      // pendingCount excludes abandoned items, so count should now be 0
      expect(await PendingSyncQueue.pendingCount(db), 0);
    });
  });
}
