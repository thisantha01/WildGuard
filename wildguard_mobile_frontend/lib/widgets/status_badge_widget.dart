import 'package:flutter/material.dart';
import '../models/sync_status.dart';

/// Status tag badge strictly implementing Color Psychology rules.
class StatusBadgeWidget extends StatelessWidget {
  final SyncStatus status;

  const StatusBadgeWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: status.color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == SyncStatus.synced
                ? Icons.check_circle_rounded
                : status == SyncStatus.pending
                    ? Icons.access_time_rounded
                    : Icons.error_outline_rounded,
            color: status.color,
            size: 14.0,
          ),
          const SizedBox(width: 4.0),
          Text(
            status.code,
            style: TextStyle(
              color: status.color,
              fontWeight: FontWeight.bold,
              fontSize: 12.0,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
