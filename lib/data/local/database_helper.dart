import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/models/detection_result.dart';
import '../../domain/models/field.dart';
import '../../domain/models/treatment_plan.dart';
import 'pending_sync_queue.dart';

class DatabaseHelper {
  static const _dbName = 'cropguard.db';
  static const _dbVersion = 14;

  static const tableDetections = 'detections';
  static const tableFields = 'fields';
  static const tableTreatmentPlans = 'treatment_plans';
  static const tableNotifications = 'notifications';

  Database? _db;
  Completer<Database>? _dbCompleter;
  String? _testPath;

  DatabaseHelper();

  DatabaseHelper.forTest(String dbName) : _testPath = dbName;

  /// Thread-safe database accessor. If two async callers both arrive before
  /// [_initDb] completes, they share a single in-flight [Completer] rather
  /// than racing to create two separate [Database] instances.
  Future<Database> get database async {
    if (_db != null) return _db!;
    if (_dbCompleter != null) return _dbCompleter!.future;
    _dbCompleter = Completer<Database>();
    try {
      _db = await _initDb();
      _dbCompleter!.complete(_db!);
    } catch (e, s) {
      final c = _dbCompleter!;
      _dbCompleter = null; // allow retry on next call
      c.completeError(e, s);
      rethrow;
    }
    return _db!;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _dbCompleter = null;
    }
  }

  Future<Database> _initDb() async {
    final String path;
    if (_testPath != null) {
      path = inMemoryDatabasePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _dbName);
    }
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableDetections (
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
      CREATE TABLE $tableFields (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cropType TEXT NOT NULL,
        sizeHectares REAL NOT NULL DEFAULT 0,
        plantingDate INTEGER,
        userId TEXT NOT NULL DEFAULT ''
      )
    ''');

    await _createTreatmentPlansTable(db);
    await _createNotificationsTable(db);
    await db.execute(PendingSyncQueue.createTableSql);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // One if-block per version bump so each migration runs exactly once,
    // regardless of which version the user is upgrading from.
    if (oldVersion < 11) {
      // Safely add columns that may be absent in old installs. SQLite does not
      // support ADD COLUMN IF NOT EXISTS, so we inspect PRAGMA table_info first.
      await _addColumnIfMissing(db, tableDetections, 'userId',    "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, tableDetections, 'displayName', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, tableDetections, 'severity',  "TEXT NOT NULL DEFAULT 'unclear'");
      await _addColumnIfMissing(db, tableDetections, 'cause',     "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, tableDetections, 'treatments',"TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(db, tableFields,     'userId',    "TEXT NOT NULL DEFAULT ''");
      await _createTreatmentPlansTable(db);
      await _createNotificationsTable(db);
    }
    if (oldVersion < 12) {
      // Adds the offline pending-sync queue table.
      await db.execute(PendingSyncQueue.createTableSql);
    }
    if (oldVersion < 13) {
      // Add status column to pending_sync table.
      await _addColumnIfMissing(db, 'pending_sync', 'status', "TEXT NOT NULL DEFAULT 'pending'");
    }
    if (oldVersion < 14) {
      // Distinguishes real model diagnoses from the low-confidence /
      // engine-unavailable fallback so History can badge them honestly
      // instead of showing a fabricated disease as a confident result.
      await _addColumnIfMissing(db, tableDetections, 'isDegraded', 'INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// Adds [column] to [table] only when the column does not yet exist.
  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (!info.any((row) => row['name'] == column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createTreatmentPlansTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTreatmentPlans (
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
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableNotifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'reminder',
        isRead INTEGER NOT NULL DEFAULT 0,
        createdAtMs INTEGER NOT NULL
      )
    ''');
  }

  static const _uuid = Uuid();
  String _newId() => _uuid.v4();

  // ─── Detections ──────────────────────────────────────────────────────────

  Future<int> insertDetection(DetectionResult result) async {
    final db = await database;
    return db.insert(
      tableDetections,
      result.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DetectionResult>> getAllDetections({
    String? userId,
    int? limit,
    int? offset,
    bool? isHealthy,
    List<String>? cropTypes,
    int? dateFrom,
    int? dateTo,
    String? searchQuery,
    String? orderBy,
  }) async {
    final db = await database;
    final List<String> whereClauses = [];
    final List<Object?> whereArgs = [];

    if (userId != null) {
      whereClauses.add('userId = ?');
      whereArgs.add(userId);
    }
    if (isHealthy != null) {
      whereClauses.add('isHealthy = ?');
      whereArgs.add(isHealthy ? 1 : 0);
    }
    if (cropTypes != null && cropTypes.isNotEmpty) {
      final placeholders = List.filled(cropTypes.length, '?').join(', ');
      whereClauses.add('cropType IN ($placeholders)');
      whereArgs.addAll(cropTypes);
    }
    if (dateFrom != null) {
      whereClauses.add('timestamp >= ?');
      whereArgs.add(dateFrom);
    }
    if (dateTo != null) {
      whereClauses.add('timestamp < ?');
      whereArgs.add(dateTo);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(displayName LIKE ? OR cropType LIKE ?)');
      final likeQuery = '%${searchQuery.trim()}%';
      whereArgs.addAll([likeQuery, likeQuery]);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      tableDetections,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy ?? 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map(DetectionResult.fromMap).toList();
  }

  Future<DetectionResult?> getDetectionById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableDetections,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DetectionResult.fromMap(maps.first);
  }

  Future<List<DetectionResult>> getRecentDetections({
    String? userId,
    int limit = 5,
  }) async {
    final db = await database;
    final where = userId != null ? 'userId = ?' : null;
    final whereArgs = userId != null ? [userId] : null;
    final maps = await db.query(
      tableDetections,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(DetectionResult.fromMap).toList();
  }

  Future<void> deleteAllDetections() async {
    final db = await database;
    // Collect paths before deleting rows so we can clean up files afterward.
    final rows = await db.query(tableDetections, columns: ['imagePath']);
    await db.delete(tableDetections);
    for (final row in rows) {
      await _tryDeleteFile(row['imagePath'] as String? ?? '');
    }
  }

  Future<void> deleteDetection(int id) async {
    final db = await database;
    // Read the path first; delete the row, then the file.  If file deletion
    // fails the row is already gone so no broken reference is shown to the user.
    final rows = await db.query(
      tableDetections,
      columns: ['imagePath'],
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete(tableDetections, where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      await _tryDeleteFile(rows.first['imagePath'] as String? ?? '');
    }
  }

  /// Deletes the file at [path] if it exists. Errors are swallowed so a failed
  /// file deletion never prevents the accompanying DB operation from completing.
  /// Uses async I/O to avoid blocking the Dart event loop on slow storage.
  Future<void> _tryDeleteFile(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Re-assigns all detections that belong to [fromUserId] to [toUserId].
  /// Used when an anonymous guest upgrades to a real account.
  Future<void> reassignDetections(String fromUserId, String toUserId) async {
    final db = await database;
    await db.update(
      tableDetections,
      {'userId': toUserId},
      where: 'userId = ?',
      whereArgs: [fromUserId],
    );
  }

  Future<int> countDetectionsForUser(String userId) async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableDetections WHERE userId = ?',
            [userId],
          ),
        ) ??
        0;
  }

  Future<List<String>> getDistinctCropTypes({String? userId}) async {
    final db = await database;
    final where = userId != null ? ' WHERE userId = ?' : '';
    final args = userId != null ? [userId] : null;
    final list = await db.rawQuery(
      'SELECT DISTINCT cropType FROM $tableDetections$where ORDER BY cropType ASC',
      args,
    );
    return list.map((row) => row['cropType'] as String).toList();
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  Future<Map<String, int>> getFarmStats({String? userId}) async {
    final db = await database;
    final userArgs = userId != null ? [userId] : <Object?>[];
    final total = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableDetections'
            '${userId != null ? ' WHERE userId = ?' : ''}',
            userArgs,
          ),
        ) ??
        0;
    final healthy = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableDetections WHERE isHealthy = 1'
            '${userId != null ? ' AND userId = ?' : ''}',
            userArgs,
          ),
        ) ??
        0;
    return {
      'total': total,
      'healthy': healthy,
      'diseased': total - healthy,
    };
  }

  Future<int> getDistinctDiseaseCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT diseaseLabel) FROM $tableDetections WHERE isHealthy = 0',
          ),
        ) ??
        0;
  }

  Future<int> getActiveDayStreak() async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT date(timestamp / 1000, 'unixepoch')) as days
      FROM $tableDetections
      WHERE timestamp >= ?
    ''', [cutoff]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getDailyTrend(
      {int days = 7, String? userId}) async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final args = userId != null ? [cutoff, userId] : <Object?>[cutoff];
    return db.rawQuery('''
      SELECT
        date(timestamp / 1000, 'unixepoch') as day,
        SUM(CASE WHEN isHealthy = 1 THEN 1 ELSE 0 END) as healthyCount,
        SUM(CASE WHEN isHealthy = 0 THEN 1 ELSE 0 END) as diseasedCount
      FROM $tableDetections
      WHERE timestamp >= ?${userId != null ? ' AND userId = ?' : ''}
      GROUP BY day
      ORDER BY day ASC
    ''', args);
  }

  // ─── Fields ───────────────────────────────────────────────────────────────

  Future<void> upsertField(Field field) async {
    final db = await database;
    await db.insert(
      tableFields,
      field.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Field>> getFields({String? userId}) async {
    final db = await database;
    final where = userId != null ? 'userId = ?' : null;
    final whereArgs = userId != null ? [userId] : null;
    final maps = await db.query(
      tableFields,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map(Field.fromMap).toList();
  }

  Future<void> deleteField(String id) async {
    final db = await database;
    await db.delete(tableFields, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Treatment Plans ─────────────────────────────────────────────────────

  Future<String> insertTreatment(TreatmentPlan plan) async {
    final db = await database;
    final payload = plan.id.isEmpty ? plan.copyWith(completed: plan.completed) : plan;
    final id = payload.id.isEmpty ? _newId() : payload.id;
    await db.insert(
      tableTreatmentPlans,
      {
        ...payload.toMap(),
        'id': id,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<TreatmentPlan>> getAllTreatments({
    String? userId,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final where = userId != null ? 'userId = ?' : null;
    final whereArgs = userId != null ? [userId] : null;
    final maps = await db.query(
      tableTreatmentPlans,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'dueDateMs ASC',
      limit: limit,
      offset: offset,
    );
    return maps.map(TreatmentPlan.fromMap).toList();
  }

  Future<void> updateTreatmentCompleted(String id, bool completed) async {
    final db = await database;
    await db.update(
      tableTreatmentPlans,
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTreatment(String id) async {
    final db = await database;
    await db.delete(tableTreatmentPlans, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCompletedTreatmentsCount({String? userId}) async {
    final db = await database;
    final where = userId != null ? ' WHERE userId = ? AND completed = 1' : ' WHERE completed = 1';
    final args = userId != null ? [userId] : null;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableTreatmentPlans$where',
            args,
          ),
        ) ??
        0;
  }

  Future<int> getPendingTreatmentsCount({String? userId}) async {
    final db = await database;
    final where = userId != null ? ' WHERE userId = ? AND completed = 0' : ' WHERE completed = 0';
    final args = userId != null ? [userId] : null;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableTreatmentPlans$where',
            args,
          ),
        ) ??
        0;
  }


  // ─── Notifications ───────────────────────────────────────────────────────

  Future<String> insertNotification(AppNotification notification) async {
    final db = await database;
    final id = notification.id.isEmpty ? _newId() : notification.id;
    await db.insert(
      tableNotifications,
      {
        ...notification.toMap(),
        'id': id,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<AppNotification>> getNotifications() async {
    final db = await database;
    final maps = await db.query(
      tableNotifications,
      orderBy: 'createdAtMs DESC',
    );
    return maps.map(AppNotification.fromMap).toList();
  }

  Future<int> getUnreadNotificationsCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableNotifications WHERE isRead = 0',
          ),
        ) ??
        0;
  }

  Future<void> markNotificationsAsRead() async {
    final db = await database;
    await db.update(tableNotifications, {'isRead': 1});
  }

  Future<void> markNotificationRead(String id) async {
    final db = await database;
    await db.update(
      tableNotifications,
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNotification(String id) async {
    final db = await database;
    await db.delete(tableNotifications, where: 'id = ?', whereArgs: [id]);
  }

  // Backward-compatible wrappers.
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final items = await getNotifications();
    return items.map((item) => item.toMap()).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    return getUnreadNotificationsCount();
  }

  Future<void> markAllNotificationsRead() async {
    await markNotificationsAsRead();
  }
}
