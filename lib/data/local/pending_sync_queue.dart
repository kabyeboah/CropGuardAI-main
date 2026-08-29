import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/di/service_locator.dart';
import '../../core/utils/analytics_service.dart';
import '../../core/utils/app_logger.dart';
import 'database_helper.dart';

/// Operation types that can be queued when the device is offline.
enum PendingSyncType {
  communityPost,
  outbreakReport,
  feedbackCorrection,
  expertRequest,
  /// A "crop not found" report (missing crop / novel disease submission).
  cropNotFound,
  /// Upload scan history result to Cloud Firestore.
  scanUpload,
  /// Add treatment plan to Cloud Firestore.
  treatmentAdd,
  /// Update treatment plan in Cloud Firestore.
  treatmentUpdate,
  /// Delete treatment plan from Cloud Firestore.
  treatmentDelete,
  /// Low confidence scan captured as training candidate for active learning.
  trainingCandidate,
  /// Flagged/reported community post submitted for moderation.
  reportedPost,
}

/// A lightweight SQLite-backed queue that stores failed cloud writes so they
/// can be retried when connectivity is restored.
///
/// This is intentionally not a WorkManager-style background isolate — for the
/// P0 pilot it drains in-process (on the UI isolate) when [drain] is called,
/// which the app triggers on the [ConnectivityService.statusStream] transition
/// from offline → online.
class PendingSyncQueue {
  PendingSyncQueue._();

  static const _table = 'pending_sync';
  static const maxRetries = 5;
  static bool _isDraining = false;
  static final _countController = StreamController<int>.broadcast();

  /// Stream of changes to pending items count.
  static Stream<int> get countStream => _countController.stream;

  @visibleForTesting
  static void resetDraining() => _isDraining = false;

  // ---------------------------------------------------------------------------
  // Schema — called from DatabaseHelper.onCreate / onUpgrade
  // ---------------------------------------------------------------------------

  /// Returns the CREATE TABLE SQL for inclusion in [DatabaseHelper]'s schema.
  static String get createTableSql => '''
    CREATE TABLE IF NOT EXISTS $_table (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      type        TEXT    NOT NULL,
      payload     TEXT    NOT NULL,
      status      TEXT    NOT NULL DEFAULT 'pending',
      retry_count INTEGER NOT NULL DEFAULT 0,
      created     INTEGER NOT NULL
    )
  ''';

  // ---------------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------------

  /// Recursively converts non-JSON-encodable sentinel values (such as Cloud
  /// Firestore [FieldValue] sentinels or raw [DateTime] objects) into primitive
  /// strings so [jsonEncode] will never throw a [JsonUnsupportedObjectError].
  static Map<String, dynamic> sanitizePayload(Map<String, dynamic> payload) {
    return payload.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;
    if (value is num || value is String || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is Map<String, dynamic>) return sanitizePayload(value);
    if (value is Map) {
      return sanitizePayload(value.map((k, v) => MapEntry(k.toString(), v)));
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    // Default fallback for FieldValue or unrecognized objects: convert to ISO string.
    return DateTime.now().toIso8601String();
  }

  /// Stores an operation locally so it can be replayed later.
  ///
  /// [type] identifies the operation; [payload] is a JSON-encodable map that
  /// the corresponding repository method can reconstruct from.
  static Future<void> enqueue(
    Database db, {
    required PendingSyncType type,
    required Map<String, dynamic> payload,
  }) async {
    await db.insert(_table, {
      'type': type.name,
      'payload': jsonEncode(sanitizePayload(payload)),
      'status': 'pending',
      'retry_count': 0,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    AppLogger.i('PendingSyncQueue: queued ${type.name}');
    await notifyCount(db);
  }

  static Future<void> notifyCount(Database db) async {
    try {
      final count = await pendingCount(db);
      if (!_countController.isClosed) {
        _countController.add(count);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Drain
  // ---------------------------------------------------------------------------

  /// Retrieves all pending entries, calls [handler] for each, and removes
  /// successfully replayed entries.
  ///
  /// [handler] receives the row [id], [PendingSyncType] and decoded payload. Return
  /// `true` to mark the entry as replayed (and delete it from the queue);
  /// return `false` to keep it for a future retry.
  static Future<void> drain(
    Database db, {
    required Future<bool> Function(int id, PendingSyncType type, Map<String, dynamic> payload) handler,
  }) async {
    if (_isDraining) {
      AppLogger.i('PendingSyncQueue: drain is already in progress, skipping concurrent run');
      return;
    }
    _isDraining = true;
    try {
      final rows = await db.query(_table, where: "status != 'abandoned'", orderBy: 'created ASC');
      if (rows.isEmpty) return;

      AppLogger.i('PendingSyncQueue: draining ${rows.length} pending operation(s)');
      try {
        if (sl.isRegistered<AnalyticsService>()) {
          unawaited(sl<AnalyticsService>().logOfflineQueueDrain(count: rows.length));
        }
      } catch (_) {}

      for (final row in rows) {
        final id = row['id'] as int;
        final currentRetries = (row['retry_count'] as int?) ?? 0;
        final typeString = row['type'] as String?;
        final type = PendingSyncType.values.where((e) => e.name == typeString).firstOrNull;

        if (type == null) {
          await db.update(
            _table,
            {'status': 'abandoned'},
            where: 'id = ?',
            whereArgs: [id],
          );
          AppLogger.e('PendingSyncQueue: unrecognized operation type "$typeString" for row #$id, marked as abandoned');
          continue;
        }
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        // Update status to syncing
        await db.update(_table, {'status': 'syncing'}, where: 'id = ?', whereArgs: [id]);

        try {
          final success = await handler(id, type, payload);
          if (success) {
            await db.delete(_table, where: 'id = ?', whereArgs: [id]);
            AppLogger.i('PendingSyncQueue: replayed and removed ${type.name}#$id');
          } else {
            final nextRetries = currentRetries + 1;
            final newStatus = nextRetries >= maxRetries ? 'abandoned' : 'failed';
            await db.update(
              _table,
              {'status': newStatus, 'retry_count': nextRetries},
              where: 'id = ?',
              whereArgs: [id],
            );
            AppLogger.w('PendingSyncQueue: handler returned false for ${type.name}#$id (retries: $nextRetries, status: $newStatus)');
          }
        } catch (e) {
          final nextRetries = currentRetries + 1;
          final newStatus = nextRetries >= maxRetries ? 'abandoned' : 'failed';
          await db.update(
            _table,
            {'status': newStatus, 'retry_count': nextRetries},
            where: 'id = ?',
            whereArgs: [id],
          );
          AppLogger.w('PendingSyncQueue: replay failed for ${type.name}#$id: $e (retries: $nextRetries, status: $newStatus)');
        }
      }
    } finally {
      _isDraining = false;
      await notifyCount(db);
    }
  }

  /// Updates the payload of a pending sync queue item.
  static Future<void> updatePayload(
    Database db,
    int id,
    Map<String, dynamic> payload,
  ) async {
    await db.update(
      _table,
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [id],
    );
    AppLogger.i('PendingSyncQueue: updated payload for item #$id');
  }

  /// Retrieves pending items filtered by type.
  static Future<List<Map<String, dynamic>>> getPendingItems(
    Database db, {
    PendingSyncType? type,
  }) async {
    if (type == null) {
      return await db.query(_table, orderBy: 'created ASC');
    } else {
      return await db.query(
        _table,
        where: 'type = ?',
        whereArgs: [type.name],
        orderBy: 'created ASC',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Introspection
  // ---------------------------------------------------------------------------

  /// Returns the count of actionable pending items (useful for a UI badge or
  /// debug view). Excludes [status] = 'abandoned' rows because those have
  /// exceeded [maxRetries] and will never be drained — counting them would
  /// permanently inflate the badge with items the app cannot resolve.
  static Future<int> pendingCount(Database db) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM $_table WHERE status != 'abandoned'",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Clears items from the pending sync queue.
  ///
  /// - If [abandonedOnly] is `true`, only drops rows with `status = 'abandoned'`
  ///   (items that exceeded [maxRetries] and will not be replayed). In-flight / pending
  ///   items are preserved so offline scans or offline edits are not discarded when signing out.
  /// - If [userId] is specified, only items belonging to that user ID (matched in the payload) are deleted.
  /// - If neither is specified, all items in the queue are deleted.
  static Future<void> clear(
    Database db, {
    String? userId,
    bool abandonedOnly = false,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      final rows = await db.query(
        _table,
        where: abandonedOnly ? "status = 'abandoned'" : null,
      );
      final idsToDelete = <int>[];
      for (final row in rows) {
        try {
          final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          if (payload['userId'] == userId || payload['authorId'] == userId) {
            idsToDelete.add(row['id'] as int);
          }
        } catch (_) {}
      }
      if (idsToDelete.isNotEmpty) {
        final placeholders = List.filled(idsToDelete.length, '?').join(',');
        await db.delete(
          _table,
          where: 'id IN ($placeholders)',
          whereArgs: idsToDelete,
        );
      }
    } else if (abandonedOnly) {
      await db.delete(_table, where: "status = 'abandoned'");
    } else {
      await db.delete(_table);
    }
    await notifyCount(db);
  }

  /// Best-effort attempt to drain the pending sync queue within [timeout]
  /// (e.g. before sign-out or app teardown) before removing completed items.
  static Future<void> drainWithTimeout(
    Database db, {
    required Future<bool> Function(int id, PendingSyncType type, Map<String, dynamic> payload) handler,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      await drain(db, handler: handler).timeout(timeout);
    } catch (e) {
      AppLogger.w('PendingSyncQueue: drainWithTimeout timed out or failed: $e');
    }
  }
}
