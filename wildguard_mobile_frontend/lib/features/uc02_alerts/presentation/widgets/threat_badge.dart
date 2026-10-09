import 'package:flutter/material.dart';
import '../../domain/enums/threat_level.dart';

/// Threat level badge pill.  Uses icon + text so level is not colour-only.
class ThreatBadge extends StatelessWidget {
  final ThreatLevel level;

  const ThreatBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.badgeColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${level.displayLabel} THREAT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
