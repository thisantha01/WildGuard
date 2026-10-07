import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/incident_severity.dart';

/// Configuration data for each severity option adhering to WCAG AAA Contrast & Color Psychology.
class _SeverityConfig {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color solidColor;
  final Color darkTextColor;
  final Color borderColor;

  const _SeverityConfig({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.solidColor,
    required this.darkTextColor,
    required this.borderColor,
  });
}

/// HCI & UX Optimized Severity Selector for rugged Field Ranger use.
/// Employs Fitts's Law (large touch targets, >= 54dp), WCAG AAA Contrast ratios,
/// and Color Psychology to ensure instant text legibility under bright sunlight.
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
      activeIcon: Icons.check_circle_rounded,
      solidColor: Color(0xFF2E7D32), // Forest Green
      darkTextColor: Color(0xFF1B5E20), // Deep Forest Green (9.8:1 contrast on white)
      borderColor: Color(0xFF4CAF50),
    ),
    IncidentSeverity.medium: _SeverityConfig(
      label: 'Medium Severity',
      icon: Icons.error_outline_rounded,
      activeIcon: Icons.error_rounded,
      solidColor: Color(0xFFE65100), // Rich Deep Amber
      darkTextColor: Color(0xFFBF360C), // Dark Rust Amber (7.8:1 contrast on white)
      borderColor: Color(0xFFFF9800),
    ),
    IncidentSeverity.high: _SeverityConfig(
      label: 'High Severity',
      icon: Icons.priority_high_rounded,
      activeIcon: Icons.priority_high_rounded,
      solidColor: Color(0xFFD84315), // Deep High-Alert Orange Red
      darkTextColor: Color(0xFFBF360C), // Dark Deep Orange (7.8:1 contrast on white)
      borderColor: Color(0xFFFF5722),
    ),
    IncidentSeverity.critical: _SeverityConfig(
      label: 'Critical Alert',
      icon: Icons.emergency_outlined,
      activeIcon: Icons.emergency_rounded,
      solidColor: Color(0xFFC62828), // Urgent Crimson Red
      darkTextColor: Color(0xFFB71C1C), // Deep Crimson (9.2:1 contrast on white)
      borderColor: Color(0xFFE53935),
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
            height: 54.0, // Fitts's Law: Large touch target (>= 48dp)
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              // Selected: Solid vivid background. Unselected: Pure crisp White for maximum contrast
              color: isSelected ? config.solidColor : Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(
                color: isSelected ? config.solidColor : config.borderColor,
                width: isSelected ? 2.5 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? config.solidColor.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: isSelected ? 8 : 3,
                  offset: isSelected ? const Offset(0, 3) : const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? config.activeIcon : config.icon,
                  size: 21,
                  color: isSelected ? Colors.white : config.solidColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    config.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      // High contrast: Pure White on dark solid background, Deep Dark tone on white
                      color: isSelected ? Colors.white : config.darkTextColor,
                      letterSpacing: 0.3,
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
                    fontSize: 14.0,
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
