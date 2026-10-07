import '../models/incident_model.dart';

/// Clean Architecture Repository Contract for Incidents.
abstract class IncidentRepository {
  Future<void> saveIncidentLocally(IncidentModel incident);
  Future<List<IncidentModel>> getAllIncidents();
  Future<List<IncidentModel>> getPendingIncidents();
  Future<Map<String, dynamic>> syncSingleIncident(IncidentModel incident);
  Future<void> markIncidentAsSynced(
    String localId,
    String serverId, {
    bool? duplicateFlag,
  });
  Future<void> markIncidentAsFailed(String localId);
  Future<List<IncidentModel>> fetchRemoteIncidentHistory();
}
