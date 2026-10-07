import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// Location section widget featuring offline placeholder map and fallback pin dropper.
class LocationPickerWidget extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isGpsLost;
  final VoidCallback onFetchGps;
  final VoidCallback onDropPin;

  const LocationPickerWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isGpsLost,
    required this.onFetchGps,
    required this.onDropPin,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCoordinates = latitude != null && longitude != null;

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
            // Header
            Row(
              children: [
                const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Incident Location (GPS)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: onFetchGps,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Detect GPS', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Map Placeholder Container
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.forest_rounded,
                    size: 70,
                    color: Colors.green.shade100,
                  ),
                  if (hasCoordinates)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 36),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Lat: ${latitude!.toStringAsFixed(4)}, Lon: ${longitude!.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (isGpsLost)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_off_rounded, color: AppColors.offlineBannerRed),
                          SizedBox(width: 6),
                          Text(
                            AppStrings.gpsLostText,
                            style: TextStyle(
                              color: AppColors.offlineBannerRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'No location selected yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Prominent Fallback Button: [ Drop Pin on Offline Map ]
            ElevatedButton.icon(
              onPressed: onDropPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: isGpsLost ? AppColors.pendingAmber : Colors.grey.shade800,
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
}
