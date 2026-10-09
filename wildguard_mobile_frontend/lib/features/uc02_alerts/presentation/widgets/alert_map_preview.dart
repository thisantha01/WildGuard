import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/alert_detail.dart';
import '../constants/uc02_constants.dart';

/// Static map preview using `flutter_map` + OpenStreetMap (no paid API keys).
///
/// Shows three markers:
///  🔴 Animal breach location
///  🔵 Ranger position (if distanceToRangerKm > 0 and we have ranger coords
///     — we approximate from the detail's lat/lng + heading; in practice the
///     ranger's GPS comes from [LocationService] and is passed in)
///  🟡 Nearest village (approximate — we only have its name from the API)
///
/// No routing, no live tracking.
class AlertMapPreview extends StatelessWidget {
  final AlertDetail detail;

  /// Optional ranger position from [LocationService].
  final LatLng? rangerPosition;

  const AlertMapPreview({
    super.key,
    required this.detail,
    this.rangerPosition,
  });

  @override
  Widget build(BuildContext context) {
    final animalPos = LatLng(detail.lat, detail.lng);

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: animalPos,
            initialZoom: Uc02Constants.mapDefaultZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none, // static — no pan/zoom gestures
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wildguard.mobile',
            ),
            MarkerLayer(
              markers: [
                _buildMarker(
                  animalPos,
                  Icons.crisis_alert_rounded,
                  Colors.red,
                  'Animal breach location',
                ),
                if (rangerPosition != null)
                  _buildMarker(
                    rangerPosition!,
                    Icons.person_pin_circle_rounded,
                    Colors.blue,
                    'Your current position',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildMarker(
    LatLng point,
    IconData icon,
    Color color,
    String semanticLabel,
  ) {
    return Marker(
      point: point,
      width: Uc02Constants.mapMarkerSize,
      height: Uc02Constants.mapMarkerSize,
      child: Semantics(
        label: semanticLabel,
        child: Icon(icon, color: color, size: Uc02Constants.mapMarkerSize),
      ),
    );
  }
}
