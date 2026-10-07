import 'package:flutter/foundation.dart';

/// Application-wide numeric and configuration constants.
class AppConstants {
  AppConstants._();

  // Local Database
  static const String databaseName = 'wildguard_offline.db';
  static const int databaseVersion = 1;
  static const String tableIncidents = 'offline_incidents';

  // API Backend Defaults (Spring Boot Backend)
  // When running on Chrome/Web/Windows, localhost:8080 is reachable directly.
  // When running inside Android Emulator, 10.0.2.2 maps to host PC localhost.
  static String get defaultApiBaseUrl => kIsWeb
      ? 'http://localhost:8080/api'
      : 'http://10.0.2.2:8080/api';

  // Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String rangerProfileEndpoint = '/rangers/me';
  static const String syncEndpoint = '/incidents/sync';
  static const String batchSyncEndpoint = '/incidents/sync/batch';

  // Mock / Default Coordinates for Offline Map Pin (e.g. Yala National Park Sector)
  static const double defaultReserveLatitude = 6.3685;
  static const double defaultReserveLongitude = 81.5273;

  // UI Dimensions (Fitts's Law touch targets)
  static const double largeTouchTargetHeight = 56.0;
  static const double photoTargetHeight = 52.0;
  static const double thumbnailHeight = 140.0;
  static const double standardPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double borderRadius = 10.0;
}
