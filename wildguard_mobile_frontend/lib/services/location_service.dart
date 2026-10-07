import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';

/// GPS location service with graceful offline/jungle fallback handling.
class LocationService {
  /// Fetches current GPS coordinates if device sensors and permissions permit.
  Future<Map<String, double>?> getCurrentCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (_) {
      // Return null on GPS timeout or hardware error in dense jungle
      return null;
    }
  }

  /// Provides fallback coordinates for offline map pin dropping.
  Map<String, double> getFallbackReserveCoordinates() {
    return {
      'latitude': AppConstants.defaultReserveLatitude,
      'longitude': AppConstants.defaultReserveLongitude,
    };
  }
}
