import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/alert_action.dart';
import '../../domain/entities/alert_summary.dart';
import '../../domain/enums/action_queue_status.dart';
import '../../domain/enums/alert_status.dart';

/// UC02 local SQLite tables:
///   - `uc02_cached_alerts` — last-fetched alert list + detail JSON blob
///   - `uc02_action_queue` — offline ranger action queue
///
/// This helper opens the SAME database file as [DatabaseService]
/// but bumps the schema version to 2 so `onUpgrade` can add the new tables
/// without touching the UC01 table.
class Uc02DatabaseHelper {
  static const String _dbName = 'wildguard_offline.db';
  static const int _dbVersion = 2;

  static const String tableAlerts = 'uc02_cached_alerts';
  static const String tableActionQueue = 'uc02_action_queue';

  Database? _db;

  // In-memory fallback for web environments
  final List<AlertSummary> _webAlerts = [];
  final Map<String, String> _webDetails = {};
  final List<AlertAction> _webActionQueue = [];

  /// Opens (or creates) the shared database, ensuring UC02 tables exist.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    if (kIsWeb) {
      throw UnsupportedError('sqflite is not supported on web.');
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createUc01Tables(db);
        await _createUc02Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createUc02Tables(db);
        }
      },
    );
    return _db!;
  }

  /// Recreates the UC01 `offline_incidents` table so `onCreate` also works
  /// for fresh installs that skip straight to v2.
  Future<void> _createUc01Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_incidents (
        local_incident_id TEXT PRIMARY KEY,
        server_incident_id TEXT,
        ranger_id TEXT,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        description TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        photo_path TEXT,
        photo_base64 TEXT,
        timestamp TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        synced_at TEXT,
        duplicate_flag INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createUc02Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAlerts (
        id TEXT PRIMARY KEY,
        display_code TEXT,
        animal_name TEXT,
        animal_tag TEXT,
        species TEXT,
        zone_name TEXT,
        zone_type TEXT,
        lat REAL,
        lng REAL,
        breach_time TEXT,
        threat_level TEXT,
        status TEXT,
        approximate_location INTEGER DEFAULT 0,
        detail_json TEXT,
        cached_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableActionQueue (
        client_action_id TEXT PRIMARY KEY,
        alert_id TEXT NOT NULL,
        type TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        payload_json TEXT,
        queue_status TEXT NOT NULL DEFAULT 'PENDING',
        retry_count INTEGER NOT NULL DEFAULT 0,
        failure_reason TEXT
      )
    ''');
  }

  // ─── Alert cache CRUD ─────────────────────────────────────────────────────

  /// Upserts a list of [AlertSummary] objects into the local cache.
  Future<void> upsertAlerts(List<AlertSummary> alerts) async {
    if (kIsWeb) {
      for (final a in alerts) {
        final idx = _webAlerts.indexWhere((x) => x.id == a.id);
        if (idx >= 0) {
          _webAlerts[idx] = a;
        } else {
          _webAlerts.add(a);
        }
      }
      return;
    }
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final alert in alerts) {
      final row = alert.toMap();
      row['cached_at'] = now;
      batch.insert(
        tableAlerts,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Retrieves all cached alerts, most recent breach-time first.
  Future<List<AlertSummary>> getCachedAlerts() async {
    if (kIsWeb) return List.unmodifiable(_webAlerts);
    final db = await database;
    final rows = await db.query(tableAlerts, orderBy: 'breach_time DESC');
    return rows.map(AlertSummary.fromMap).toList();
  }

  /// Stores a raw detail JSON blob alongside the existing summary row.
  Future<void> upsertDetailJson(String alertId, String detailJson) async {
    if (kIsWeb) {
      _webDetails[alertId] = detailJson;
      return;
    }
    final db = await database;
    await db.update(
      tableAlerts,
      {'detail_json': detailJson},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  /// Returns the cached detail JSON blob for [alertId], or null.
  Future<String?> getDetailJson(String alertId) async {
    if (kIsWeb) return _webDetails[alertId];
    final db = await database;
    final rows = await db.query(
      tableAlerts,
      columns: ['detail_json'],
      where: 'id = ?',
      whereArgs: [alertId],
    );
    if (rows.isEmpty) return null;
    return rows.first['detail_json'] as String?;
  }

  /// Updates only the status column of a cached alert row.
  Future<void> updateAlertStatus(String alertId, String statusJson) async {
    if (kIsWeb) {
      final idx = _webAlerts.indexWhere((x) => x.id == alertId);
      if (idx >= 0) {
        _webAlerts[idx] = _webAlerts[idx].copyWith(status: AlertStatus.fromJson(statusJson));
      }
      return;
    }
    final db = await database;
    await db.update(
      tableAlerts,
      {'status': statusJson},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  // ─── Action queue CRUD ────────────────────────────────────────────────────

  /// Inserts a new [AlertAction] into the queue with status PENDING.
  Future<void> enqueueAction(AlertAction action) async {
    if (kIsWeb) {
      _webActionQueue.removeWhere((a) => a.clientActionId == action.clientActionId);
      _webActionQueue.add(action);
      return;
    }
    final db = await database;
    await db.insert(
      tableActionQueue,
      action.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Returns all PENDING actions ordered by [occurredAt] ascending.
  Future<List<AlertAction>> getPendingActions() async {
    if (kIsWeb) {
      return _webActionQueue
          .where((a) => a.queueStatus == ActionQueueStatus.pending)
          .toList();
    }
    final db = await database;
    final rows = await db.query(
      tableActionQueue,
      where: 'queue_status = ?',
      whereArgs: [ActionQueueStatus.pending.toJson()],
      orderBy: 'occurred_at ASC',
    );
    return rows.map(AlertAction.fromMap).toList();
  }

  /// Returns the total count of PENDING actions.
  Future<int> getPendingCount() async {
    if (kIsWeb) {
      return _webActionQueue
          .where((a) => a.queueStatus == ActionQueueStatus.pending)
          .length;
    }
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM $tableActionQueue WHERE queue_status = 'PENDING'",
    );
    return result.first['c'] as int? ?? 0;
  }

  /// Updates queue_status for a given [clientActionId].
  Future<void> updateActionStatus(
    String clientActionId,
    ActionQueueStatus status, {
    String? failureReason,
  }) async {
    if (kIsWeb) {
      final idx = _webActionQueue.indexWhere((a) => a.clientActionId == clientActionId);
      if (idx >= 0) {
        _webActionQueue[idx] = _webActionQueue[idx].copyWith(
          queueStatus: status,
          failureReason: failureReason,
        );
      }
      return;
    }
    final db = await database;
    final data = <String, dynamic>{'queue_status': status.toJson()};
    if (failureReason != null) data['failure_reason'] = failureReason;
    await db.update(
      tableActionQueue,
      data,
      where: 'client_action_id = ?',
      whereArgs: [clientActionId],
    );
  }

  /// Increments [retry_count] by 1 for [clientActionId].
  Future<void> incrementRetry(String clientActionId) async {
    if (kIsWeb) {
      final idx = _webActionQueue.indexWhere((a) => a.clientActionId == clientActionId);
      if (idx >= 0) {
        _webActionQueue[idx] = _webActionQueue[idx].copyWith(
          retryCount: _webActionQueue[idx].retryCount + 1,
        );
      }
      return;
    }
    final db = await database;
    await db.rawUpdate(
      'UPDATE $tableActionQueue SET retry_count = retry_count + 1 WHERE client_action_id = ?',
      [clientActionId],
    );
  }

  /// Serialises the full detail response JSON for caching.
  static String encodeDetail(Map<String, dynamic> json) => jsonEncode(json);

  /// Decodes the cached detail JSON blob.
  static Map<String, dynamic>? decodeDetail(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
