import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/enums/crop_damage.dart';
import '../../domain/enums/injury_severity.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import '../widgets/offline_banner.dart';

/// Screen 5 — Report Saved / Confirmation.
///
/// Green check + "Report saved." message.
/// Shows "Alert ALT-xxxx will be RESOLVED after sync" (offline) or
/// "Report sent" (online).
/// Summary chip row with crop damage, injuries, safe status.
/// "Back to Alerts" button.
class ReportSavedScreen extends StatelessWidget {
  final String alertId;
  final String displayCode;
  final CropDamage cropDamage;
  final InjurySeverity injuries;
  final bool wasOnline;

  const ReportSavedScreen({
    super.key,
    required this.alertId,
    required this.displayCode,
    required this.cropDamage,
    required this.injuries,
    required this.wasOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        return PopScope(
          canPop: false, // prevent back-swipe into the form
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              title: const Text('Report Submitted'),
              automaticallyImplyLeading: false,
            ),
            body: Column(
              children: [
                OfflineBanner(isOnline: provider.isOnline),
                Expanded(child: _buildContent(context, provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, AlertsProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(Uc02Constants.screenPadding * 1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Success icon ───────────────────────────────────────────────
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.syncedGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // ── Main message ───────────────────────────────────────────────
          const Text(
            'Report Saved.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            wasOnline
                ? 'Report sent. Alert $displayCode will be RESOLVED shortly.'
                : 'Alert $displayCode will be RESOLVED after sync with base.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: Uc02Constants.minBodyFontSize,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          // ── Summary chips ──────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SummaryChip(
                icon: Icons.grass_rounded,
                label: 'Crop: ${cropDamage.displayLabel}',
                color: _cropColor(cropDamage),
              ),
              _SummaryChip(
                icon: Icons.medical_services_rounded,
                label: 'Injuries: ${injuries.displayLabel}',
                color: _injuryColor(injuries),
              ),
              const _SummaryChip(
                icon: Icons.shield_rounded,
                label: 'Situation: Safe',
                color: AppColors.syncedGreen,
              ),
            ],
          ),
          const SizedBox(height: 40),

          // ── Back to alerts ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: Uc02Constants.primaryButtonHeight,
            child: ElevatedButton.icon(
              onPressed: () {
                // Pop all routes on the UC02 stack back to the list
                Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                );
                provider.loadAlerts();
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text(
                'BACK TO ALERTS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _cropColor(CropDamage d) {
    switch (d) {
      case CropDamage.none:
        return AppColors.syncedGreen;
      case CropDamage.minor:
        return AppColors.pendingAmber;
      case CropDamage.major:
        return AppColors.failedRed;
    }
  }

  Color _injuryColor(InjurySeverity i) {
    switch (i) {
      case InjurySeverity.none:
        return AppColors.syncedGreen;
      case InjurySeverity.human:
      case InjurySeverity.animal:
        return AppColors.failedRed;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: Uc02Constants.minLabelFontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
