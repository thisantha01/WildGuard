import 'package:flutter/material.dart';

/// App color palette adhering to Color Psychology for mission-critical operations.
class AppColors {
  AppColors._();

  // Primary & Ranger Theme
  static const Color primary = Color(0xFF1B5E20); // Deep Forest Green
  static const Color primaryDark = Color(0xFF003300);
  static const Color primaryLight = Color(0xFF4C8C4A);
  static const Color accent = Color(0xFF81C784);

  // Status Colors (Color Psychology)
  static const Color offlineBannerRed = Color(0xFFD32F2F); // High Alert Red
  static const Color pendingAmber = Color(0xFFF57C00); // Amber / Orange for Pending
  static const Color syncedGreen = Color(0xFF2E7D32); // Green for Confirmed Synced
  static const Color failedRed = Color(0xFFC62828); // Error Red

  // Color Aliases for Semantic Clarity
  static const Color greenSyncSuccess = syncedGreen;
  static const Color amberSyncPending = pendingAmber;
  static const Color redOfflineAlert = offlineBannerRed;

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF5F7F5);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE0E0E0);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textLight = Colors.white;
}
