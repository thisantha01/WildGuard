import '../models/incident_model.dart';
import '../models/sync_status.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'incident_repository.dart';

/// Implementation of IncidentRepository coordinating SQLite and remote REST API.
class IncidentRepositoryImpl implements IncidentRepository {
  final DatabaseService databaseService;
  final ApiService apiService;

  IncidentRepositoryImpl({
    required this.databaseService,
    required this.apiService,
  });

  @override
  Future<void> saveIncidentLocally(IncidentModel incident) async {
    await databaseService.insertIncident(incident);
  }

  @override
  Future<List<IncidentModel>> getAllIncidents() async {
    return await databaseService.getAllIncidents();
  }

  @override
  Future<List<IncidentModel>> getPendingIncidents() async {
    return await databaseService.getPendingIncidents();
  }

  @override
  Future<Map<String, dynamic>> syncSingleIncident(IncidentModel incident) async {
    return await apiService.syncIncident(incident);
  }

  @override
  Future<void> markIncidentAsSynced(
    String localId,
    String serverId, {
    bool? duplicateFlag,
  }) async {
    await databaseService.updateIncidentStatus(
      localId,
      SyncStatus.synced,
      serverId: serverId,
      duplicateFlag: duplicateFlag,
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<void> markIncidentAsFailed(String localId) async {
    await databaseService.updateIncidentStatus(
      localId,
      SyncStatus.failed,
    );
  }

  @override
  Future<List<IncidentModel>> fetchRemoteIncidentHistory() async {
    final rawList = await apiService.fetchMyIncidentHistory();
    final List<IncidentModel> list = [];
    for (final json in rawList) {
      final incident = IncidentModel.fromApiJson(json);
      await databaseService.insertIncident(incident);
      list.add(incident);
    }
    return list;
  }
}
