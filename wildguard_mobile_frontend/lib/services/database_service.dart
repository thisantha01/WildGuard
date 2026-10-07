import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/incident_model.dart';
import '../models/sync_status.dart';

/// Database service wrapping local SQLite storage via sqflite,
/// with persistent browser storage fallback (SharedPreferences) for web demonstrations.
class DatabaseService {
  Database? _db;
  static final List<IncidentModel> _webStorage = [];
  static const String _webStorageKey = 'wildguard_web_incidents';
  static bool _webStorageLoaded = false;

  static Future<void> _ensureWebStorageLoaded() async {
    if (!kIsWeb || _webStorageLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _webStorage.clear();
        for (final item in list) {
          _webStorage.add(IncidentModel.fromMap(item as Map<String, dynamic>));
        }
      }
      _webStorageLoaded = true;
    } catch (e) {
      debugPrint('⚠️ [LOCAL DB - WEB] Could not load persisted web storage: $e');
    }
  }

  static Future<void> _persistWebStorage() async {
    if (!kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_webStorage.map((i) => i.toMap()).toList());
      await prefs.setString(_webStorageKey, data);
    } catch (e) {
      debugPrint('⚠️ [LOCAL DB - WEB] Could not save persisted web storage: $e');
    }
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('sqflite is not supported on web.');
    }
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.databaseName);

      return await openDatabase(
        path,
        version: AppConstants.databaseVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${AppConstants.tableIncidents} (
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
        },
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to initialize local SQLite database', e.toString());
    }
  }

  /// Inserts a new incident into the local database.
  Future<void> insertIncident(IncidentModel incident) async {
    if (kIsWeb) {
      await _ensureWebStorageLoaded();
      final index = _webStorage.indexWhere((i) =>
          i.localIncidentId == incident.localIncidentId ||
          (i.serverIncidentId != null &&
              incident.serverIncidentId != null &&
              i.serverIncidentId == incident.serverIncidentId));
      if (index >= 0) {
        _webStorage[index] = incident;
      } else {
        _webStorage.insert(0, incident);
      }
      await _persistWebStorage();
      debugPrint('🗄️ [LOCAL DB - WEB] Saved to persistent local storage. Total records stored: ${_webStorage.length}');
      return;
    }

    try {
      final db = await database;
      if (incident.serverIncidentId != null) {
        final existing = await db.query(
          AppConstants.tableIncidents,
          where: 'server_incident_id = ?',
          whereArgs: [incident.serverIncidentId],
        );
        if (existing.isNotEmpty) {
          await db.update(
            AppConstants.tableIncidents,
            incident.toMap(),
            where: 'server_incident_id = ?',
            whereArgs: [incident.serverIncidentId],
          );
          return;
        }
      }
      await db.insert(
        AppConstants.tableIncidents,
        incident.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to save offline incident', e.toString());
    }
  }

  /// Retrieves all incidents sorted by timestamp descending.
  Future<List<IncidentModel>> getAllIncidents() async {
    if (kIsWeb) {
      await _ensureWebStorageLoaded();
      return List.unmodifiable(_webStorage);
    }

    try {
      final db = await database;
      final results = await db.query(
        AppConstants.tableIncidents,
        orderBy: 'timestamp DESC',
      );
      return results.map((row) => IncidentModel.fromMap(row)).toList();
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch incidents', e.toString());
    }
  }

  /// Retrieves all pending and failed incidents awaiting synchronization.
  Future<List<IncidentModel>> getPendingIncidents() async {
    if (kIsWeb) {
      await _ensureWebStorageLoaded();
      return _webStorage
          .where((i) => i.syncStatus == SyncStatus.pending || i.syncStatus == SyncStatus.failed)
          .toList();
    }

    try {
      final db = await database;
      final results = await db.query(
        AppConstants.tableIncidents,
        where: 'sync_status = ? OR sync_status = ?',
        whereArgs: [SyncStatus.pending.code, SyncStatus.failed.code],
        orderBy: 'timestamp ASC',
      );
      return results.map((row) => IncidentModel.fromMap(row)).toList();
    } catch (e) {
      throw LocalDatabaseException('Failed to fetch pending incidents', e.toString());
    }
  }

  /// Updates the sync status and server ID after a sync attempt.
  Future<void> updateIncidentStatus(
    String localId,
    SyncStatus status, {
    String? serverId,
    bool? duplicateFlag,
    DateTime? syncedAt,
  }) async {
    if (kIsWeb) {
      await _ensureWebStorageLoaded();
      final index = _webStorage.indexWhere((i) =>
          i.localIncidentId == localId ||
          (serverId != null && i.serverIncidentId == serverId));
      if (index >= 0) {
        final existing = _webStorage[index];
        _webStorage[index] = existing.copyWith(
          syncStatus: status,
          serverIncidentId: serverId ?? existing.serverIncidentId,
          duplicateFlag: duplicateFlag ?? existing.duplicateFlag,
          syncedAt: syncedAt ?? existing.syncedAt,
        );
        await _persistWebStorage();
      }
      return;
    }

    try {
      final db = await database;
      final updateData = <String, dynamic>{
        'sync_status': status.code,
      };

      if (serverId != null) {
        updateData['server_incident_id'] = serverId;
      }
      if (duplicateFlag != null) {
        updateData['duplicate_flag'] = duplicateFlag ? 1 : 0;
      }
      if (syncedAt != null) {
        updateData['synced_at'] = syncedAt.toIso8601String();
      }

      await db.update(
        AppConstants.tableIncidents,
        updateData,
        where: 'local_incident_id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw LocalDatabaseException('Failed to update incident status', e.toString());
    }
  }

  /// Closes database connection.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
