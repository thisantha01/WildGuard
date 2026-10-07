import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/incident_model.dart';
import '../models/incident_severity.dart';
import '../models/sync_status.dart';
import '../viewmodels/offline_sync_manager.dart';
import 'status_badge_widget.dart';

/// Clean card displaying saved offline incident details and sync status.
class IncidentCardWidget extends StatelessWidget {
  final IncidentModel incident;
  final VoidCallback? onRetry;

  const IncidentCardWidget({
    super.key,
    required this.incident,
    this.onRetry,
  });

  void _defaultRetry(BuildContext context) async {
    try {
      final manager = context.read<OfflineSyncManager>();
      final ok = await manager.retrySingleIncident(incident);
      if (!context.mounted) return;
      final msg = ok
          ? 'Incident synced successfully with base station!'
          : (manager.errorMessage ?? 'Sync failed. Please verify connection and login.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? AppColors.syncedGreen : AppColors.failedRed,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // Ignored if provider not present in test harness
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.standardPadding,
        vertical: 6.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type Title and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          incident.type.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(incident.severity).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getSeverityColor(incident.severity), width: 0.8),
                        ),
                        child: Text(
                          incident.severity.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getSeverityColor(incident.severity),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (incident.syncStatus == SyncStatus.failed) ...[
                      InkWell(
                        key: Key('retry_button_${incident.localIncidentId}'),
                        onTap: onRetry ?? () => _defaultRetry(context),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.failedRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.failedRed, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 13, color: AppColors.failedRed),
                              SizedBox(width: 3),
                              Text(
                                'RETRY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.failedRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    StatusBadgeWidget(status: incident.syncStatus),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6.0),

            // Description and optional photo thumbnail
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    incident.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (incident.photoBase64 != null && incident.photoBase64!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildPhotoThumbnail(incident.photoBase64!),
                ],
              ],
            ),
            const SizedBox(height: 8.0),

            // Metadata: GPS and Timestamp
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')} · ${incident.timestamp.day}/${incident.timestamp.month}/${incident.timestamp.year}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (incident.syncStatus == SyncStatus.failed) ...[
              const SizedBox(height: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.failedRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.failedRed.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.failedRed),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Upload unconfirmed. Verify internet & login, then tap RETRY.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.failedRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low:
        return const Color(0xFF2E7D32);
      case IncidentSeverity.medium:
        return const Color(0xFFE65100);
      case IncidentSeverity.high:
        return const Color(0xFFD84315);
      case IncidentSeverity.critical:
        return const Color(0xFFB71C1C);
    }
  }

  Widget _buildPhotoThumbnail(String rawBase64) {
    try {
      final cleanBase64 = rawBase64.contains(',')
          ? rawBase64.split(',').last
          : rawBase64;
      final bytes = base64Decode(cleanBase64.trim());
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
