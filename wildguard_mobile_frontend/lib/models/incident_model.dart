import 'incident_severity.dart';
import 'incident_type.dart';
import 'sync_status.dart';

/// Clean Architecture Data Model for Field Incidents.
class IncidentModel {
  final String localIncidentId;
  final String? serverIncidentId;
  final String? rangerId;
  final IncidentType type;
  final IncidentSeverity severity;
  final String description;
  final double latitude;
  final double longitude;
  final String? photoPath;
  final String? photoBase64;
  final DateTime timestamp;
  final SyncStatus syncStatus;
  final DateTime? syncedAt;
  final bool duplicateFlag;

  const IncidentModel({
    required this.localIncidentId,
    this.serverIncidentId,
    this.rangerId,
    required this.type,
    required this.severity,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.photoPath,
    this.photoBase64,
    required this.timestamp,
    this.syncStatus = SyncStatus.pending,
    this.syncedAt,
    this.duplicateFlag = false,
  });

  /// Serializes into SQLite key-value row.
  Map<String, dynamic> toMap() {
    return {
      'local_incident_id': localIncidentId,
      'server_incident_id': serverIncidentId,
      'ranger_id': rangerId,
      'type': type.code,
      'severity': severity.code,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'photo_path': photoPath,
      'photo_base64': photoBase64,
      'timestamp': timestamp.toIso8601String(),
      'sync_status': syncStatus.code,
      'synced_at': syncedAt?.toIso8601String(),
      'duplicate_flag': duplicateFlag ? 1 : 0,
    };
  }

  /// Deserializes from SQLite row map.
  factory IncidentModel.fromMap(Map<String, dynamic> map) {
    return IncidentModel(
      localIncidentId: map['local_incident_id'] as String,
      serverIncidentId: map['server_incident_id'] as String?,
      rangerId: map['ranger_id'] as String?,
      type: IncidentType.fromCode(map['type'] as String),
      severity: IncidentSeverity.fromCode(map['severity'] as String),
      description: map['description'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      photoPath: map['photo_path'] as String?,
      photoBase64: map['photo_base64'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      syncStatus: SyncStatus.fromCode(map['sync_status'] as String),
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
      duplicateFlag: (map['duplicate_flag'] as int?) == 1,
    );
  }

  /// Serializes into REST API payload for Spring Boot backend (`/api/incidents/sync`).
  Map<String, dynamic> toApiPayload() {
    return {
      'localIncidentId': localIncidentId,
      'type': type.code,
      'severity': severity.code,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'photoBase64': photoBase64,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  IncidentModel copyWith({
    String? localIncidentId,
    String? serverIncidentId,
    String? rangerId,
    IncidentType? type,
    IncidentSeverity? severity,
    String? description,
    double? latitude,
    double? longitude,
    String? photoPath,
    String? photoBase64,
    DateTime? timestamp,
    SyncStatus? syncStatus,
    DateTime? syncedAt,
    bool? duplicateFlag,
  }) {
    return IncidentModel(
      localIncidentId: localIncidentId ?? this.localIncidentId,
      serverIncidentId: serverIncidentId ?? this.serverIncidentId,
      rangerId: rangerId ?? this.rangerId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoPath: photoPath ?? this.photoPath,
      photoBase64: photoBase64 ?? this.photoBase64,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: syncedAt ?? this.syncedAt,
      duplicateFlag: duplicateFlag ?? this.duplicateFlag,
    );
  }
}
