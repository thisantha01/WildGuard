import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/incident_severity.dart';

/// Configuration data for each severity option adhering to Color Psychology.
class _SeverityConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _SeverityConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// HCI & UX Optimized Severity Selector for rugged Field Ranger use.
/// Employs Fitts's Law (large touch targets) and Color Psychology.
class SeveritySelectorWidget extends StatelessWidget {
  final IncidentSeverity selectedSeverity;
  final ValueChanged<IncidentSeverity> onSeverityChanged;

  const SeveritySelectorWidget({
    super.key,
    required this.selectedSeverity,
    required this.onSeverityChanged,
  });

  static const Map<IncidentSeverity, _SeverityConfig> _configs = {
    IncidentSeverity.low: _SeverityConfig(
      label: 'Low Severity',
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFF2E7D32), // Forest Green
    ),
    IncidentSeverity.medium: _SeverityConfig(
      label: 'Medium Severity',
      icon: Icons.error_outline_rounded,
      color: Color(0xFFEF6C00), // Amber / Orange
    ),
    IncidentSeverity.high: _SeverityConfig(
      label: 'High Severity',
      icon: Icons.priority_high_rounded,
      color: Color(0xFFE65100), // Deep Orange / Crimson
    ),
    IncidentSeverity.critical: _SeverityConfig(
      label: 'Critical Alert',
      icon: Icons.emergency_rounded,
      color: Color(0xFFC62828), // Urgent Red
    ),
  };

  Widget _buildSeverityButton(IncidentSeverity severity) {
    final config = _configs[severity]!;
    final isSelected = selectedSeverity == severity;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('severity_${severity.name}'),
          onTap: () => onSeverityChanged(severity),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            height: 52.0, // Fitts's Law: Large touch target (>= 48dp)
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? config.color : config.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: isSelected ? config.color : config.color.withValues(alpha: 0.4),
                width: isSelected ? 2.0 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: config.color.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  config.icon,
                  size: 20,
                  color: isSelected ? Colors.white : config.color,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    config.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : config.color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            const Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Incident Severity Level *',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.0,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2x2 Grid: Row 1 (Low & Medium)
            Row(
              children: [
                _buildSeverityButton(IncidentSeverity.low),
                const SizedBox(width: 10),
                _buildSeverityButton(IncidentSeverity.medium),
              ],
            ),
            const SizedBox(height: 10),

            // 2x2 Grid: Row 2 (High & Critical)
            Row(
              children: [
                _buildSeverityButton(IncidentSeverity.high),
                const SizedBox(width: 10),
                _buildSeverityButton(IncidentSeverity.critical),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
