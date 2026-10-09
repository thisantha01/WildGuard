import 'package:flutter/material.dart';
import '../../domain/enums/alert_status.dart';

/// Compact status chip.  Always shows both an icon and a text label
/// so status is never conveyed by colour alone (accessibility requirement).
class StatusChip extends StatelessWidget {
  final AlertStatus status;
  final bool small;

  const StatusChip({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 11.0 : 12.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: fontSize + 2, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status.displayLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
