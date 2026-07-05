import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

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

  // ---------------------------------------------------------------------------
  // Schema — called from DatabaseHelper.onCreate / onUpgrade
  // ---------------------------------------------------------------------------

  /// Returns the CREATE TABLE SQL for inclusion in [DatabaseHelper]'s schema.
  static String get createTableSql => '''
    CREATE TABLE IF NOT EXISTS $_table (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      type      TEXT    NOT NULL,
      payload   TEXT    NOT NULL,
      created   INTEGER NOT NULL
    )
  ''';

  // ---------------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------------

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
      'payload': jsonEncode(payload),
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    AppLogger.i('PendingSyncQueue: queued ${type.name}');
  }

  // ---------------------------------------------------------------------------
  // Drain
  // ---------------------------------------------------------------------------

  /// Retrieves all pending entries, calls [handler] for each, and removes
  /// successfully replayed entries.
  ///
  /// [handler] receives the [PendingSyncType] and decoded payload. Return
  /// `true` to mark the entry as replayed (and delete it from the queue);
  /// return `false` to keep it for a future retry.
  static Future<void> drain(
    Database db, {
    required Future<bool> Function(PendingSyncType type, Map<String, dynamic> payload) handler,
  }) async {
    final rows = await db.query(_table, orderBy: 'created ASC');
    if (rows.isEmpty) return;

    AppLogger.i('PendingSyncQueue: draining ${rows.length} pending operation(s)');

    for (final row in rows) {
      final type = PendingSyncType.values.firstWhere(
        (e) => e.name == row['type'] as String,
        orElse: () => PendingSyncType.communityPost,
      );
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

      try {
        final success = await handler(type, payload);
        if (success) {
          await db.delete(_table, where: 'id = ?', whereArgs: [row['id']]);
          AppLogger.i('PendingSyncQueue: replayed and removed ${type.name}#${row['id']}');
        }
      } catch (e) {
        // Keep the entry; it will be retried on the next drain call.
        AppLogger.w('PendingSyncQueue: replay failed for ${type.name}#${row['id']}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Introspection
  // ---------------------------------------------------------------------------

  /// Returns the count of pending items (useful for a UI badge or debug view).
  static Future<int> pendingCount(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return (result.first['c'] as int?) ?? 0;
  }

  /// Drops all pending items — use when the user signs out to avoid leaking
  /// another user's queued operations.
  static Future<void> clear(Database db) async {
    await db.delete(_table);
  }
}
