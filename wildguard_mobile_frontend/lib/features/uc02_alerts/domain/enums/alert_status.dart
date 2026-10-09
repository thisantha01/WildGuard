import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// All possible states in the UC02 alert lifecycle state machine.
/// Mirrors the backend `AlertStatus` enum exactly.
enum AlertStatus {
  newAlert,
  notified,
  acknowledged,
  inProgress,
  pendingResolution,
  resolved,
  escalated,
  deliveryFailed;

  /// Parses the backend JSON string value (e.g. "IN_PROGRESS") to this enum.
  static AlertStatus fromJson(String? raw) {
    switch (raw) {
      case 'NEW':
        return AlertStatus.newAlert;
      case 'NOTIFIED':
        return AlertStatus.notified;
      case 'ACKNOWLEDGED':
        return AlertStatus.acknowledged;
      case 'IN_PROGRESS':
        return AlertStatus.inProgress;
      case 'PENDING_RESOLUTION':
        return AlertStatus.pendingResolution;
      case 'RESOLVED':
        return AlertStatus.resolved;
      case 'ESCALATED':
        return AlertStatus.escalated;
      case 'DELIVERY_FAILED':
        return AlertStatus.deliveryFailed;
      default:
        return AlertStatus.newAlert;
    }
  }

  /// Returns the backend wire-format string for this status.
  String toJson() {
    switch (this) {
      case AlertStatus.newAlert:
        return 'NEW';
      case AlertStatus.notified:
        return 'NOTIFIED';
      case AlertStatus.acknowledged:
        return 'ACKNOWLEDGED';
      case AlertStatus.inProgress:
        return 'IN_PROGRESS';
      case AlertStatus.pendingResolution:
        return 'PENDING_RESOLUTION';
      case AlertStatus.resolved:
        return 'RESOLVED';
      case AlertStatus.escalated:
        return 'ESCALATED';
      case AlertStatus.deliveryFailed:
        return 'DELIVERY_FAILED';
    }
  }

  /// Human-readable label shown on chips.
  String get displayLabel {
    switch (this) {
      case AlertStatus.newAlert:
        return 'NEW';
      case AlertStatus.notified:
        return 'NOTIFIED';
      case AlertStatus.acknowledged:
        return 'ACKNOWLEDGED';
      case AlertStatus.inProgress:
        return 'IN PROGRESS';
      case AlertStatus.pendingResolution:
        return 'PENDING RESOLUTION';
      case AlertStatus.resolved:
        return 'RESOLVED';
      case AlertStatus.escalated:
        return 'ESCALATED';
      case AlertStatus.deliveryFailed:
        return 'DELIVERY FAILED';
    }
  }

  /// Icon for accessibility — status never conveyed by colour alone.
  IconData get icon {
    switch (this) {
      case AlertStatus.newAlert:
        return Icons.fiber_new_rounded;
      case AlertStatus.notified:
        return Icons.notifications_active_rounded;
      case AlertStatus.acknowledged:
        return Icons.check_circle_outline_rounded;
      case AlertStatus.inProgress:
        return Icons.directions_run_rounded;
      case AlertStatus.pendingResolution:
        return Icons.hourglass_top_rounded;
      case AlertStatus.resolved:
        return Icons.task_alt_rounded;
      case AlertStatus.escalated:
        return Icons.warning_amber_rounded;
      case AlertStatus.deliveryFailed:
        return Icons.error_outline_rounded;
    }
  }

  /// Chip background colour — always paired with an icon for accessibility.
  Color get chipColor {
    switch (this) {
      case AlertStatus.newAlert:
        return AppColors.pendingAmber;
      case AlertStatus.notified:
        return AppColors.failedRed;
      case AlertStatus.acknowledged:
        return AppColors.primary;
      case AlertStatus.inProgress:
        return AppColors.primary;
      case AlertStatus.pendingResolution:
        return AppColors.pendingAmber;
      case AlertStatus.resolved:
        return AppColors.syncedGreen;
      case AlertStatus.escalated:
        return AppColors.failedRed;
      case AlertStatus.deliveryFailed:
        return const Color(0xFF757575);
    }
  }
}
