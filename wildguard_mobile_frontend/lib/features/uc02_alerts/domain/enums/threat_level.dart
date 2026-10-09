import 'package:flutter/material.dart';

/// Threat severity classification mirroring the backend `ThreatLevel` enum.
enum ThreatLevel {
  low,
  moderate,
  high;

  static ThreatLevel fromJson(String? raw) {
    switch (raw) {
      case 'HIGH':
        return ThreatLevel.high;
      case 'MODERATE':
        return ThreatLevel.moderate;
      case 'LOW':
      default:
        return ThreatLevel.low;
    }
  }

  String toJson() => name.toUpperCase();

  String get displayLabel {
    switch (this) {
      case ThreatLevel.low:
        return 'LOW';
      case ThreatLevel.moderate:
        return 'MODERATE';
      case ThreatLevel.high:
        return 'HIGH';
    }
  }

  Color get badgeColor {
    switch (this) {
      case ThreatLevel.low:
        return const Color(0xFF2E7D32);
      case ThreatLevel.moderate:
        return const Color(0xFFF57C00);
      case ThreatLevel.high:
        return const Color(0xFFC62828);
    }
  }

  /// Icon for accessibility — level never conveyed by colour alone.
  IconData get icon {
    switch (this) {
      case ThreatLevel.low:
        return Icons.shield_outlined;
      case ThreatLevel.moderate:
        return Icons.warning_amber_rounded;
      case ThreatLevel.high:
        return Icons.crisis_alert_rounded;
    }
  }
}
