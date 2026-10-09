import '../enums/alert_status.dart';
import '../enums/threat_level.dart';

/// Immutable domain entity for an alert list item.
/// Corresponds to [AlertSummaryResponse] from the backend.
class AlertSummary {
  final String id;
  final String displayCode;
  final String animalName;
  final String? animalTag;
  final String? species;
  final String zoneName;
  final String? zoneType;
  final double lat;
  final double lng;
  final DateTime breachTime;
  final ThreatLevel threatLevel;
  final AlertStatus status;
  final bool approximateLocation;

  const AlertSummary({
    required this.id,
    required this.displayCode,
    required this.animalName,
    this.animalTag,
    this.species,
    required this.zoneName,
    this.zoneType,
    required this.lat,
    required this.lng,
    required this.breachTime,
    required this.threatLevel,
    required this.status,
    required this.approximateLocation,
  });

  /// Constructs from backend JSON response map.
  factory AlertSummary.fromJson(Map<String, dynamic> json) {
    return AlertSummary(
      id: json['id'] as String,
      displayCode: json['displayCode'] as String? ?? '',
      animalName: json['animalName'] as String? ?? 'Unknown',
      animalTag: json['animalTag'] as String?,
      species: json['species'] as String?,
      zoneName: json['zoneName'] as String? ?? 'Unknown',
      zoneType: json['zoneType'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      breachTime: _parseInstant(json['breachTime']),
      threatLevel: ThreatLevel.fromJson(json['threatLevel'] as String?),
      status: AlertStatus.fromJson(json['status'] as String?),
      approximateLocation: json['approximateLocation'] as bool? ?? false,
    );
  }

  /// Serialises for local SQLite `uc02_cached_alerts` row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_code': displayCode,
      'animal_name': animalName,
      'animal_tag': animalTag,
      'species': species,
      'zone_name': zoneName,
      'zone_type': zoneType,
      'lat': lat,
      'lng': lng,
      'breach_time': breachTime.toIso8601String(),
      'threat_level': threatLevel.toJson(),
      'status': status.toJson(),
      'approximate_location': approximateLocation ? 1 : 0,
      'detail_json': null, // filled by detail cache
    };
  }

  /// Deserialises from a SQLite row.
  factory AlertSummary.fromMap(Map<String, dynamic> map) {
    return AlertSummary(
      id: map['id'] as String,
      displayCode: map['display_code'] as String? ?? '',
      animalName: map['animal_name'] as String? ?? 'Unknown',
      animalTag: map['animal_tag'] as String?,
      species: map['species'] as String?,
      zoneName: map['zone_name'] as String? ?? 'Unknown',
      zoneType: map['zone_type'] as String?,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      breachTime: DateTime.parse(map['breach_time'] as String),
      threatLevel: ThreatLevel.fromJson(map['threat_level'] as String?),
      status: AlertStatus.fromJson(map['status'] as String?),
      approximateLocation: (map['approximate_location'] as int? ?? 0) == 1,
    );
  }

  /// Returns a copy with [status] replaced (used for optimistic UI updates).
  AlertSummary copyWith({AlertStatus? status}) {
    return AlertSummary(
      id: id,
      displayCode: displayCode,
      animalName: animalName,
      animalTag: animalTag,
      species: species,
      zoneName: zoneName,
      zoneType: zoneType,
      lat: lat,
      lng: lng,
      breachTime: breachTime,
      threatLevel: threatLevel,
      status: status ?? this.status,
      approximateLocation: approximateLocation,
    );
  }

  static DateTime _parseInstant(dynamic raw) {
    if (raw == null) return DateTime.now();
    return DateTime.parse(raw.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AlertSummary && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
