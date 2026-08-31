import 'dart:io';

import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  int testCounter = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cg_migration_test_');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  String getUniqueDbPath() {
    testCounter++;
    return p.join(tempDir.path, 'migration_test_$testCounter.db');
  }

  // Helper to inspect table columns
  Future<List<String>> getColumnNames(Database db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.map((row) => row['name'] as String).toList();
  }

  // Helper to check index existence
  Future<bool> indexExists(Database db, String indexName) async {
    final info = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      [indexName],
    );
    return info.isNotEmpty;
  }

  group('Database Schema Migrations', () {
    test('Fresh installation creates version 17 with all tables and columns',
        () async {
      final dbPath = getUniqueDbPath();
      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;

      final version = await db.getVersion();
      expect(version, 17);

      // Check tables
      final detectionCols =
          await getColumnNames(db, DatabaseHelper.tableDetections);
      expect(
          detectionCols,
          containsAll([
            'id',
            'userId',
            'imagePath',
            'diseaseLabel',
            'displayName',
            'confidence',
            'severity',
            'isHealthy',
            'cropType',
            'cause',
            'treatments',
            'timestamp',
            'isDegraded',
            'modelVersion',
            'isSynced',
            'syncedAt',
          ]));

      final fieldCols = await getColumnNames(db, DatabaseHelper.tableFields);
      expect(
          fieldCols,
          containsAll([
            'id',
            'name',
            'cropType',
            'sizeHectares',
            'plantingDate',
            'userId',
          ]));

      final treatmentCols =
          await getColumnNames(db, DatabaseHelper.tableTreatmentPlans);
      expect(
          treatmentCols,
          containsAll([
            'id',
            'userId',
            'detectionId',
            'cropType',
            'diseaseName',
            'step',
            'completed',
            'dueDateMs',
            'createdAtMs',
          ]));

      final notifCols =
          await getColumnNames(db, DatabaseHelper.tableNotifications);
      expect(
          notifCols,
          containsAll([
            'id',
            'userId',
            'title',
            'body',
            'type',
            'isRead',
            'createdAtMs',
          ]));

      final pendingCols = await getColumnNames(db, 'pending_sync');
      expect(
          pendingCols,
          containsAll([
            'id',
            'type',
            'payload',
            'status',
            'retry_count',
            'created',
          ]));

      expect(await indexExists(db, 'idx_detections_userId_isSynced'), isTrue);

      await helper.close();
    });

    test(
        'Upgrade from v10 -> v17 preserves existing detections & adds missing columns/tables',
        () async {
      final dbPath = getUniqueDbPath();

      // 1. Create a legacy v10 database
      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                confidence REAL NOT NULL,
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                timestamp INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableFields} (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                cropType TEXT NOT NULL,
                sizeHectares REAL NOT NULL DEFAULT 0,
                plantingDate INTEGER
              )
            ''');
          },
        ),
      );

      // Seed v10 data
      await legacyDb.insert(DatabaseHelper.tableDetections, {
        'imagePath': '/legacy/path1.jpg',
        'diseaseLabel': 'tomato_blight',
        'confidence': 0.88,
        'isHealthy': 0,
        'cropType': 'tomato',
        'timestamp': 1600000000000,
      });

      await legacyDb.insert(DatabaseHelper.tableFields, {
        'id': 'field_legacy_1',
        'name': 'North Farm',
        'cropType': 'tomato',
        'sizeHectares': 1.5,
        'plantingDate': 1590000000000,
      });

      await legacyDb.close();

      // 2. Open via DatabaseHelper to trigger _onUpgrade (v10 -> v17)
      final helper = DatabaseHelper.forTest(dbPath);
      final upgradedDb = await helper.database;

      final newVersion = await upgradedDb.getVersion();
      expect(newVersion, 17);

      // Verify v10 detection was preserved with default values for new columns
      final detections = await helper.getAllDetections();
      expect(detections.length, 1);
      final d = detections.first;
      expect(d.imagePath, '/legacy/path1.jpg');
      expect(d.diseaseLabel, 'tomato_blight');
      expect(d.confidence, 0.88);
      expect(d.isHealthy, isFalse);
      expect(d.cropType, 'tomato');
      expect(d.timestamp, 1600000000000);
      expect(d.userId, '');
      expect(d.displayName, '');
      expect(d.severity, 'unclear');
      expect(d.cause, '');
      expect(d.treatments, isEmpty);
      expect(d.isDegraded, isFalse);
      expect(d.modelVersion, isNull);
      expect(d.isSynced, isFalse);
      expect(d.syncedAt, isNull);

      // Verify field was preserved
      final fields = await helper.getFields();
      expect(fields.length, 1);
      expect(fields.first.id, 'field_legacy_1');
      expect(fields.first.userId, '');

      // Verify newly added tables work
      final tid = await helper.insertTreatment(TreatmentPlan(
        id: '',
        userId: 'user1',
        detectionId: d.id,
        cropType: 'tomato',
        diseaseName: 'tomato_blight',
        step: 'Spray copper fungicide',
        completed: false,
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      expect(tid, isNotEmpty);

      await helper.close();
    });

    test(
        'Upgrade from v11 -> v17 creates pending_sync and all modern columns & indexes',
        () async {
      final dbPath = getUniqueDbPath();

      // 1. Create v11 database
      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT NOT NULL DEFAULT '',
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                displayName TEXT NOT NULL,
                confidence REAL NOT NULL,
                severity TEXT NOT NULL DEFAULT 'unclear',
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                cause TEXT NOT NULL DEFAULT '',
                treatments TEXT NOT NULL DEFAULT '',
                timestamp INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableFields} (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                cropType TEXT NOT NULL,
                sizeHectares REAL NOT NULL DEFAULT 0,
                plantingDate INTEGER,
                userId TEXT NOT NULL DEFAULT ''
              )
            ''');
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableTreatmentPlans} (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL DEFAULT '',
                detectionId INTEGER NOT NULL DEFAULT 0,
                cropType TEXT NOT NULL,
                diseaseName TEXT NOT NULL,
                step TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0,
                dueDateMs INTEGER NOT NULL,
                createdAtMs INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableNotifications} (
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL DEFAULT '',
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                type TEXT NOT NULL DEFAULT 'reminder',
                isRead INTEGER NOT NULL DEFAULT 0,
                createdAtMs INTEGER NOT NULL
              )
            ''');
          },
        ),
      );

      await legacyDb.insert(DatabaseHelper.tableDetections, {
        'userId': 'farmer_joe',
        'imagePath': '/v11/img.jpg',
        'diseaseLabel': 'cassava_mosaic',
        'displayName': 'Cassava Mosaic Disease',
        'confidence': 0.95,
        'severity': 'high',
        'isHealthy': 0,
        'cropType': 'cassava',
        'cause': 'Begomovirus',
        'treatments': 'Remove diseased plants',
        'timestamp': 1610000000000,
      });

      await legacyDb.close();

      // 2. Upgrade to v17
      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 17);

      final cols = await getColumnNames(db, 'pending_sync');
      expect(
          cols,
          containsAll(
              ['id', 'type', 'payload', 'status', 'retry_count', 'created']));

      final detections = await helper.getAllDetections(userId: 'farmer_joe');
      expect(detections.length, 1);
      expect(detections.first.displayName, 'Cassava Mosaic Disease');
      expect(detections.first.isSynced, isFalse);
      expect(detections.first.isDegraded, isFalse);

      await helper.close();
    });

    test(
        'Upgrade from v12 -> v17 adds status, retry_count, isDegraded, modelVersion, isSynced',
        () async {
      final dbPath = getUniqueDbPath();

      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT NOT NULL DEFAULT '',
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                displayName TEXT NOT NULL,
                confidence REAL NOT NULL,
                severity TEXT NOT NULL DEFAULT 'unclear',
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                cause TEXT NOT NULL DEFAULT '',
                treatments TEXT NOT NULL DEFAULT '',
                timestamp INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE pending_sync (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                payload TEXT NOT NULL,
                created INTEGER NOT NULL
              )
            ''');
          },
        ),
      );

      await legacyDb.insert('pending_sync', {
        'type': 'communityPost',
        'payload': '{"title":"Legacy Post"}',
        'created': 1620000000000,
      });

      await legacyDb.close();

      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 17);

      final pendingRows = await db.query('pending_sync');
      expect(pendingRows.length, 1);
      expect(pendingRows.first['status'], 'pending');
      expect(pendingRows.first['retry_count'], 0);

      await helper.close();
    });

    test(
        'Upgrade from v13 -> v17 adds isDegraded, retry_count, modelVersion, isSynced, indexes',
        () async {
      final dbPath = getUniqueDbPath();

      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 13,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT NOT NULL DEFAULT '',
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                displayName TEXT NOT NULL,
                confidence REAL NOT NULL,
                severity TEXT NOT NULL DEFAULT 'unclear',
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                cause TEXT NOT NULL DEFAULT '',
                treatments TEXT NOT NULL DEFAULT '',
                timestamp INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE pending_sync (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                payload TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                created INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
      await legacyDb.close();

      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 17);

      final pendingCols = await getColumnNames(db, 'pending_sync');
      expect(pendingCols, contains('retry_count'));

      final detectionCols =
          await getColumnNames(db, DatabaseHelper.tableDetections);
      expect(detectionCols,
          containsAll(['isDegraded', 'modelVersion', 'isSynced', 'syncedAt']));

      await helper.close();
    });

    test(
        'Upgrade from v14 -> v17 adds retry_count, modelVersion, isSynced and creates indexes',
        () async {
      final dbPath = getUniqueDbPath();

      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 14,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT NOT NULL DEFAULT '',
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                displayName TEXT NOT NULL,
                confidence REAL NOT NULL,
                severity TEXT NOT NULL DEFAULT 'unclear',
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                cause TEXT NOT NULL DEFAULT '',
                treatments TEXT NOT NULL DEFAULT '',
                timestamp INTEGER NOT NULL,
                isDegraded INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE pending_sync (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                payload TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                created INTEGER NOT NULL
              )
            ''');
          },
        ),
      );

      await legacyDb.insert(DatabaseHelper.tableDetections, {
        'userId': 'user14',
        'imagePath': '/path14.jpg',
        'diseaseLabel': 'maize_rust',
        'displayName': 'Maize Rust',
        'confidence': 0.77,
        'severity': 'medium',
        'isHealthy': 0,
        'cropType': 'maize',
        'cause': 'Fungus',
        'treatments': '',
        'timestamp': 1640000000000,
        'isDegraded': 1,
      });

      await legacyDb.close();

      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 17);

      final row = (await helper.getAllDetections(userId: 'user14')).first;
      expect(row.isDegraded, isTrue);
      expect(row.isSynced, isFalse);

      expect(await indexExists(db, 'idx_detections_userId'), isTrue);

      await helper.close();
    });

    test(
        'Upgrade from v15 -> v17 adds modelVersion, isSynced, syncedAt and sync index',
        () async {
      final dbPath = getUniqueDbPath();

      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 15,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT NOT NULL DEFAULT '',
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                displayName TEXT NOT NULL,
                confidence REAL NOT NULL,
                severity TEXT NOT NULL DEFAULT 'unclear',
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                cause TEXT NOT NULL DEFAULT '',
                treatments TEXT NOT NULL DEFAULT '',
                timestamp INTEGER NOT NULL,
                isDegraded INTEGER NOT NULL DEFAULT 0
              )
            ''');
          },
        ),
      );

      await legacyDb.insert(DatabaseHelper.tableDetections, {
        'userId': 'user15',
        'imagePath': '/path15.jpg',
        'diseaseLabel': 'rice_blast',
        'displayName': 'Rice Blast',
        'confidence': 0.92,
        'severity': 'high',
        'isHealthy': 0,
        'cropType': 'rice',
        'cause': 'Magnaporthe oryzae',
        'treatments': 'Tricyclazole',
        'timestamp': 1650000000000,
        'isDegraded': 0,
      });

      await legacyDb.close();

      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 17);

      final detection = (await helper.getAllDetections(userId: 'user15')).first;
      expect(detection.modelVersion, isNull);
      expect(detection.isSynced, isFalse);
      expect(detection.syncedAt, isNull);

      // Now verify marking synced updates isSynced and syncedAt
      await helper.markDetectionSynced(detection.id, syncedAt: 1650000050000);
      final updated = await helper.getDetectionById(detection.id);
      expect(updated!.isSynced, isTrue);
      expect(updated.syncedAt, 1650000050000);

      await helper.close();
    });

    test('Upgrade from v16 -> v17 adds isSynced and syncedAt correctly',
        () async {
      final dbPath = getUniqueDbPath();

      final legacyDb = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 16,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${DatabaseHelper.tableDetections} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT NOT NULL DEFAULT '',
                imagePath TEXT NOT NULL,
                diseaseLabel TEXT NOT NULL,
                displayName TEXT NOT NULL,
                confidence REAL NOT NULL,
                severity TEXT NOT NULL DEFAULT 'unclear',
                isHealthy INTEGER NOT NULL,
                cropType TEXT NOT NULL,
                cause TEXT NOT NULL DEFAULT '',
                treatments TEXT NOT NULL DEFAULT '',
                timestamp INTEGER NOT NULL,
                isDegraded INTEGER NOT NULL DEFAULT 0,
                modelVersion TEXT
              )
            ''');
          },
        ),
      );

      await legacyDb.insert(DatabaseHelper.tableDetections, {
        'userId': 'user16',
        'imagePath': '/path16.jpg',
        'diseaseLabel': 'healthy_maize',
        'displayName': 'Healthy Maize',
        'confidence': 0.99,
        'severity': 'none',
        'isHealthy': 1,
        'cropType': 'maize',
        'cause': '',
        'treatments': '',
        'timestamp': 1660000000000,
        'isDegraded': 0,
        'modelVersion': 'v2.4.0',
      });

      await legacyDb.close();

      final helper = DatabaseHelper.forTest(dbPath);
      final db = await helper.database;
      expect(await db.getVersion(), 17);

      final row = (await helper.getAllDetections(userId: 'user16')).first;
      expect(row.modelVersion, 'v2.4.0');
      expect(row.isSynced, isFalse);
      expect(row.syncedAt, isNull);

      final unsynced = await helper.getUnsyncedDetections(userId: 'user16');
      expect(unsynced.length, 1);

      await helper.close();
    });
  });
}
