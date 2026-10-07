import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Sync status for offline incident records.
enum SyncStatus {
  pending('PENDING', 'Pending Sync', AppColors.pendingAmber),
  synced('SYNCED', 'Synchronized', AppColors.syncedGreen),
  failed('FAILED', 'Sync Failed', AppColors.failedRed);

  final String code;
  final String label;
  final Color color;

  const SyncStatus(this.code, this.label, this.color);

  static SyncStatus fromCode(String code) {
    if (code.startsWith('SYNCED')) {
      return SyncStatus.synced;
    }
    return SyncStatus.values.firstWhere(
      (status) => status.code == code || status.name == code,
      orElse: () => SyncStatus.pending,
    );
  }
}
