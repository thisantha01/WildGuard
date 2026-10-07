import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// Interactive Field Map Widget displaying live Ranger GPS location, OpenStreetMap tiles,
/// and fail-safe offline fallback controls.
class LocationPickerWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final bool isGpsLost;
  final bool isLocating;
  final VoidCallback onFetchGps;
  final VoidCallback onDropPin;
  final void Function(double lat, double lon)? onLocationChanged;

  const LocationPickerWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isGpsLost,
    this.isLocating = false,
    required this.onFetchGps,
    required this.onDropPin,
    this.onLocationChanged,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant LocationPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != null && widget.longitude != null) {
      if (widget.latitude != oldWidget.latitude || widget.longitude != oldWidget.longitude) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(
              LatLng(widget.latitude!, widget.longitude!),
              _mapController.camera.zoom > 10 ? _mapController.camera.zoom : 15.0,
            );
          } catch (_) {}
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng get _currentCenter {
    if (widget.latitude != null && widget.longitude != null) {
      return LatLng(widget.latitude!, widget.longitude!);
    }
    return const LatLng(AppConstants.defaultReserveLatitude, AppConstants.defaultReserveLongitude);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_currentCenter, (currentZoom + 1).clamp(3.0, 19.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_currentCenter, (currentZoom - 1).clamp(3.0, 19.0));
  }

  void _recenter() {
    _mapController.move(_currentCenter, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCoordinates = widget.latitude != null && widget.longitude != null;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Title, Detect GPS button
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Incident Location (GPS)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.isLocating ? null : widget.onFetchGps,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: widget.isLocating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(
                    widget.isLocating ? 'Locating...' : 'Detect GPS',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // OS Timestamp Display
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'OS Recorded Time: $timeStr · Today',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                if (hasCoordinates) ...[
                  const Spacer(),
                  const Text(
                    'Tap map to adjust pin',
                    style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Real Interactive Map Canvas
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: widget.isGpsLost
                      ? AppColors.failedRed.withValues(alpha: 0.6)
                      : (hasCoordinates ? AppColors.syncedGreen.withValues(alpha: 0.6) : Colors.grey.shade300),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                child: Stack(
                  children: [
                    // FlutterMap with OpenStreetMap Tiles
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentCenter,
                        initialZoom: hasCoordinates ? 15.0 : 13.0,
                        minZoom: 3.0,
                        maxZoom: 19.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                        onTap: (tapPosition, point) {
                          if (widget.onLocationChanged != null) {
                            widget.onLocationChanged!(point.latitude, point.longitude);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'org.wildguard.app',
                          maxZoom: 19,
                        ),
                        if (hasCoordinates)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(widget.latitude!, widget.longitude!),
                                width: 60,
                                height: 60,
                                child: _buildRangerLocationMarker(),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Top Floating Badge displaying Coordinates Pill
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: hasCoordinates ? AppColors.syncedGreen : AppColors.cardBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasCoordinates ? Icons.check_circle_rounded : Icons.location_searching,
                              size: 14,
                              color: hasCoordinates ? AppColors.syncedGreen : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              hasCoordinates
                                  ? 'Lat: ${widget.latitude!.toStringAsFixed(4)}, Lon: ${widget.longitude!.toStringAsFixed(4)}'
                                  : 'No GPS Lock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasCoordinates ? AppColors.primaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Map Zoom & Recenter Controls (Floating Toolbar on Right)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _buildMapActionButton(
                            icon: Icons.add,
                            tooltip: 'Zoom In',
                            onTap: _zoomIn,
                          ),
                          const SizedBox(height: 6),
                          _buildMapActionButton(
                            icon: Icons.remove,
                            tooltip: 'Zoom Out',
                            onTap: _zoomOut,
                          ),
                          const SizedBox(height: 6),
                          _buildMapActionButton(
                            icon: Icons.my_location,
                            tooltip: 'Center on Location',
                            onTap: _recenter,
                          ),
                        ],
                      ),
                    ),

                    // Loading State Overlay
                    if (widget.isLocating)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.25),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Acquiring exact GPS coordinates...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Prominent Warning Alert if GPS is Lost
            if (widget.isGpsLost) ...[
              const SizedBox(height: 8),
              Container(
                key: const Key('gps_lost_warning_banner'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.failedRed.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.failedRed, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WARNING: Exact GPS coordinates could not be located. Satellite signal obstructed or disabled. Tap [ Drop Pin on Offline Map ] to proceed.',
                        style: TextStyle(
                          color: AppColors.failedRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Prominent Fallback Button: [ Drop Pin on Offline Map ]
            ElevatedButton.icon(
              onPressed: widget.onDropPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isGpsLost ? AppColors.pendingAmber : Colors.grey.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
              icon: const Icon(Icons.pin_drop_rounded),
              label: const Text(
                AppStrings.dropPinButtonText,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: AppColors.textPrimary),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildRangerLocationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Radar outer circle
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            // Pin icon
            const Icon(
              Icons.location_pin,
              color: AppColors.offlineBannerRed,
              size: 32,
            ),
            // Inner center dot
            Positioned(
              top: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
