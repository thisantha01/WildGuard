import '../enums/alert_status.dart';
import '../enums/threat_level.dart';

/// Immutable domain entity for a fully-detailed alert.
/// Corresponds to [AlertDetailResponse] from the backend.
class AlertDetail {
  final String id;
  final String displayCode;
  final String animalName;
  final String? animalTag;
  final String? species;
  final String? sex;
  final String collarCode;
  final int collarBattery;
  final String collarStatus;
  final String zoneName;
  final String? zoneType;
  final double lat;
  final double lng;
  final DateTime breachTime;
  final ThreatLevel threatLevel;
  final AlertStatus status;
  final String nearestVillageName;
  final double distanceToVillageM;
  final double distanceToRangerKm;
  final int etaMinutes;
  final String safetyInstructions;
  final bool approximateLocation;
  final List<String> availableActions;
  final DateTime? acknowledgedAt;
  final DateTime? dispatchConfirmedAt;

  const AlertDetail({
    required this.id,
    required this.displayCode,
    required this.animalName,
    this.animalTag,
    this.species,
    this.sex,
    required this.collarCode,
    required this.collarBattery,
    required this.collarStatus,
    required this.zoneName,
    this.zoneType,
    required this.lat,
    required this.lng,
    required this.breachTime,
    required this.threatLevel,
    required this.status,
    required this.nearestVillageName,
    required this.distanceToVillageM,
    required this.distanceToRangerKm,
    required this.etaMinutes,
    required this.safetyInstructions,
    required this.approximateLocation,
    required this.availableActions,
    this.acknowledgedAt,
    this.dispatchConfirmedAt,
  });

  /// Constructs from backend JSON response map.
  factory AlertDetail.fromJson(Map<String, dynamic> json) {
    final rawActions = json['availableActions'];
    final actions = rawActions is List
        ? rawActions.map((e) => e as String).toList()
        : <String>[];

    return AlertDetail(
      id: json['id'] as String,
      displayCode: json['displayCode'] as String? ?? '',
      animalName: json['animalName'] as String? ?? 'Unknown',
      animalTag: json['animalTag'] as String?,
      species: json['species'] as String?,
      sex: json['sex'] as String?,
      collarCode: json['collarCode'] as String? ?? 'N/A',
      collarBattery: json['collarBattery'] as int? ?? 0,
      collarStatus: json['collarStatus'] as String? ?? 'UNKNOWN',
      zoneName: json['zoneName'] as String? ?? 'Unknown',
      zoneType: json['zoneType'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      breachTime: _parseInstant(json['breachTime']),
      threatLevel: ThreatLevel.fromJson(json['threatLevel'] as String?),
      status: AlertStatus.fromJson(json['status'] as String?),
      nearestVillageName: json['nearestVillageName'] as String? ?? 'None nearby',
      distanceToVillageM: (json['distanceToVillageM'] as num?)?.toDouble() ?? 0.0,
      distanceToRangerKm: (json['distanceToRangerKm'] as num?)?.toDouble() ?? 0.0,
      etaMinutes: json['etaMinutes'] as int? ?? 0,
      safetyInstructions: json['safetyInstructions'] as String? ??
          'Exercise caution and observe standard wildlife protocols.',
      approximateLocation: json['approximateLocation'] as bool? ?? false,
      availableActions: actions,
      acknowledgedAt: _parseInstantNullable(json['acknowledgedAt']),
      dispatchConfirmedAt: _parseInstantNullable(json['dispatchConfirmedAt']),
    );
  }

  /// Returns a copy with only [status] and [availableActions] updated
  /// (used for optimistic local updates after an offline action).
  AlertDetail copyWithStatus(AlertStatus newStatus, List<String> newActions) {
    return AlertDetail(
      id: id,
      displayCode: displayCode,
      animalName: animalName,
      animalTag: animalTag,
      species: species,
      sex: sex,
      collarCode: collarCode,
      collarBattery: collarBattery,
      collarStatus: collarStatus,
      zoneName: zoneName,
      zoneType: zoneType,
      lat: lat,
      lng: lng,
      breachTime: breachTime,
      threatLevel: threatLevel,
      status: newStatus,
      nearestVillageName: nearestVillageName,
      distanceToVillageM: distanceToVillageM,
      distanceToRangerKm: distanceToRangerKm,
      etaMinutes: etaMinutes,
      safetyInstructions: safetyInstructions,
      approximateLocation: approximateLocation,
      availableActions: newActions,
      acknowledgedAt: acknowledgedAt,
      dispatchConfirmedAt: dispatchConfirmedAt,
    );
  }

  static DateTime _parseInstant(dynamic raw) {
    if (raw == null) return DateTime.now();
    return DateTime.parse(raw.toString());
  }

  static DateTime? _parseInstantNullable(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AlertDetail && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
