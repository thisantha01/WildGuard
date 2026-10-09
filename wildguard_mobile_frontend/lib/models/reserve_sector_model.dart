import 'dart:math';

/// Reserve sector and landmark model representing official wildlife reserve sectors,
/// physical landmarks, and trail markers for offline spatial referencing.
class ReserveSectorModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final double latitude;
  final double longitude;
  final String iconType;

  const ReserveSectorModel({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.iconType,
  });

  /// Official pre-mapped sectors & landmarks for Yala National Park Reserve
  static const List<ReserveSectorModel> yalaSectors = [
    ReserveSectorModel(
      id: 'lm-1',
      name: 'Palatupana Lagoon & Ranger Gate',
      code: 'SEC-01',
      description: 'Southern park entrance, lagoon boundary & central base',
      latitude: 6.2715,
      longitude: 81.4428,
      iconType: 'hq',
    ),
    ReserveSectorModel(
      id: 'lm-2',
      name: 'Trail Marker 14 (Menik River)',
      code: 'TM-14',
      description: 'Central river crossing corridor & main patrol junction',
      latitude: 6.3685,
      longitude: 81.5273,
      iconType: 'trail',
    ),
    ReserveSectorModel(
      id: 'lm-3',
      name: 'Yala Park Bungalow & Waterhole',
      code: 'BG-01',
      description: 'Historical field outpost bungalow and high-activity wildlife watering hole',
      latitude: 6.3721,
      longitude: 81.4012,
      iconType: 'bungalow',
    ),
    ReserveSectorModel(
      id: 'lm-4',
      name: 'Patanangala Coastal Headland',
      code: 'SEC-03',
      description: 'Rocky coastal headland and southern beach patrol route',
      latitude: 6.3812,
      longitude: 81.5421,
      iconType: 'coast',
    ),
    ReserveSectorModel(
      id: 'lm-5',
      name: 'Block 1 Central Sector Waterhole',
      code: 'SEC-04',
      description: 'High-density wildlife waterhole & snare hotspot',
      latitude: 6.3550,
      longitude: 81.4720,
      iconType: 'waterhole',
    ),
    ReserveSectorModel(
      id: 'lm-6',
      name: 'Northern Boundary Buffer Zone',
      code: 'SEC-05',
      description: 'Bordering agricultural land with high poaching risk',
      latitude: 6.4102,
      longitude: 81.4891,
      iconType: 'boundary',
    ),
    ReserveSectorModel(
      id: 'lm-7',
      name: 'Kumbukkan Oya Eastern Perimeter',
      code: 'SEC-06',
      description: 'Eastern wilderness river border with Kumana sanctuary',
      latitude: 6.4521,
      longitude: 81.6712,
      iconType: 'river',
    ),
  ];

  /// Computes offset coordinates (lat, lon) given distance in meters and cardinal heading (e.g. North-East).
  /// Uses spherical geodetic displacement formula:
  /// Δlat = (d * cos(θ)) / 111,111
  /// Δlon = (d * sin(θ)) / (111,111 * cos(lat))
  static Map<String, double> computeOffsetCoordinates({
    required double baseLat,
    required double baseLon,
    required double distanceMeters,
    required String direction,
  }) {
    if (distanceMeters <= 0) {
      return {'latitude': baseLat, 'longitude': baseLon};
    }

    double bearingDeg = 0.0;
    switch (direction.toUpperCase().trim()) {
      case 'N':
      case 'NORTH':
        bearingDeg = 0.0;
        break;
      case 'NE':
      case 'NORTH-EAST':
      case 'NORTHEAST':
        bearingDeg = 45.0;
        break;
      case 'E':
      case 'EAST':
        bearingDeg = 90.0;
        break;
      case 'SE':
      case 'SOUTH-EAST':
      case 'SOUTHEAST':
        bearingDeg = 135.0;
        break;
      case 'S':
      case 'SOUTH':
        bearingDeg = 180.0;
        break;
      case 'SW':
      case 'SOUTH-WEST':
      case 'SOUTHWEST':
        bearingDeg = 225.0;
        break;
      case 'W':
      case 'WEST':
        bearingDeg = 270.0;
        break;
      case 'NW':
      case 'NORTH-WEST':
      case 'NORTHWEST':
        bearingDeg = 315.0;
        break;
    }

    final bearingRad = bearingDeg * (pi / 180.0);
    final latRad = baseLat * (pi / 180.0);

    // 1 deg latitude ≈ 111,111 meters
    final deltaLat = (distanceMeters * cos(bearingRad)) / 111111.0;
    // 1 deg longitude ≈ 111,111 * cos(lat) meters
    final deltaLon = (distanceMeters * sin(bearingRad)) / (111111.0 * cos(latRad));

    return {
      'latitude': baseLat + deltaLat,
      'longitude': baseLon + deltaLon,
    };
  }
}
