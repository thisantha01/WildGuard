import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/incident_model.dart';
import '../models/sync_status.dart';

/// Database service wrapping local SQLite storage via sqflite.
class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
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
    try {
      final db = await database;
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

  /// Retrieves all pending incidents awaiting synchronization.
  Future<List<IncidentModel>> getPendingIncidents() async {
    try {
      final db = await database;
      final results = await db.query(
        AppConstants.tableIncidents,
        where: 'sync_status = ?',
        whereArgs: [SyncStatus.pending.code],
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
