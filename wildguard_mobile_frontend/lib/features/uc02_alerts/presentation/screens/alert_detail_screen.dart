import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/alert_detail.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import '../widgets/alert_map_preview.dart';
import '../widgets/offline_banner.dart';
import '../widgets/status_chip.dart';
import '../widgets/threat_badge.dart';
import 'respond_navigate_screen.dart';

/// Screen 2 — Alert Detail (wireframe 1 "Alert Notification").
///
/// Shown when a ranger taps an alert in the list.
/// Primary action: ACKNOWLEDGE (NOTIFIED status only).
/// Secondary action: CANNOT RESPOND / decline (NOTIFIED status only).
class AlertDetailScreen extends StatefulWidget {
  final String alertId;
  const AlertDetailScreen({super.key, required this.alertId});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  bool _collarExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().loadAlertDetail(widget.alertId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text(provider.currentDetail?.displayCode ?? 'Alert Detail'),
          ),
          body: Column(
            children: [
              OfflineBanner(isOnline: provider.isOnline),
              Expanded(child: _buildBody(context, provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AlertsProvider provider) {
    switch (provider.detailState) {
      case AlertsLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case AlertsLoadState.error:
        return _ErrorBody(
          message: provider.errorMessage ?? 'Could not load detail.',
          onRetry: () => provider.loadAlertDetail(widget.alertId),
        );
      case AlertsLoadState.loaded:
      case AlertsLoadState.idle:
        final detail = provider.currentDetail;
        if (detail == null) return const SizedBox.shrink();
        return _DetailBody(
          detail: detail,
          provider: provider,
          collarExpanded: _collarExpanded,
          onCollarToggle: () =>
              setState(() => _collarExpanded = !_collarExpanded),
        );
    }
  }
}

class _DetailBody extends StatelessWidget {
  final AlertDetail detail;
  final AlertsProvider provider;
  final bool collarExpanded;
  final VoidCallback onCollarToggle;

  const _DetailBody({
    required this.detail,
    required this.provider,
    required this.collarExpanded,
    required this.onCollarToggle,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = detail.status == AlertStatus.notified;
    final isAcknowledgeInFlight =
        provider.isActionInFlight(detail.id, ActionType.acknowledge);
    final isDeclineInFlight =
        provider.isActionInFlight(detail.id, ActionType.decline);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Uc02Constants.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Alert header card ──────────────────────────────────────────
          _AlertHeaderCard(detail: detail),
          const SizedBox(height: 16),

          // ── Map preview ────────────────────────────────────────────────
          AlertMapPreview(
            detail: detail,
            rangerPosition: detail.distanceToRangerKm > 0 ? null : null,
          ),
          const SizedBox(height: 16),

          // ── Info rows ──────────────────────────────────────────────────
          _InfoCard(detail: detail),
          const SizedBox(height: 16),

          // ── Safety card ────────────────────────────────────────────────
          _SafetyCard(instructions: detail.safetyInstructions),
          const SizedBox(height: 16),

          // ── Collar details (collapsible) ───────────────────────────────
          _CollarDetails(
            detail: detail,
            expanded: collarExpanded,
            onToggle: onCollarToggle,
          ),
          const SizedBox(height: 24),

          // ── Pending sync notice ────────────────────────────────────────
          if (!provider.isOnline)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.pendingAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
                border: Border.all(color: AppColors.pendingAmber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync_outlined, color: AppColors.pendingAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved on phone — will sync automatically when online.',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          // ── Primary action: ACKNOWLEDGE ────────────────────────────────
          if (canAct || detail.status == AlertStatus.acknowledged)
            ..._buildActionsForStatus(context, detail, provider,
                isAcknowledgeInFlight, isDeclineInFlight),

          // ── Navigate to Respond screen for post-NOTIFIED statuses ──────
          if (detail.status == AlertStatus.acknowledged ||
              detail.status == AlertStatus.inProgress ||
              detail.status == AlertStatus.pendingResolution)
            _OpenRespondButton(detail: detail),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildActionsForStatus(
    BuildContext context,
    AlertDetail detail,
    AlertsProvider provider,
    bool isAcknowledgeInFlight,
    bool isDeclineInFlight,
  ) {
    if (detail.status != AlertStatus.notified) return [];

    return [
      // ACKNOWLEDGE (primary)
      Semantics(
        button: true,
        label: 'Acknowledge this alert',
        child: SizedBox(
          width: double.infinity,
          height: Uc02Constants.primaryButtonHeight,
          child: ElevatedButton.icon(
            onPressed: isAcknowledgeInFlight
                ? null
                : () => _acknowledge(context, detail, provider),
            icon: isAcknowledgeInFlight
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text(
              'ACKNOWLEDGE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
      const SizedBox(height: Uc02Constants.minButtonSpacing),

      // CANNOT RESPOND (secondary)
      Semantics(
        button: true,
        label: 'Cannot respond to this alert',
        child: SizedBox(
          width: double.infinity,
          height: Uc02Constants.primaryButtonHeight,
          child: OutlinedButton.icon(
            onPressed: isDeclineInFlight
                ? null
                : () => _showDeclineDialog(context, detail, provider),
            icon: isDeclineInFlight
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.block_rounded, color: AppColors.failedRed),
            label: const Text(
              'CANNOT RESPOND',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.failedRed),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.failedRed, width: 2),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _acknowledge(
    BuildContext context,
    AlertDetail detail,
    AlertsProvider provider,
  ) async {
    final newStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: detail.status,
      type: ActionType.acknowledge,
    );
    if (!context.mounted) return;
    if (newStatus != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert acknowledged. Proceeding to respond screen.'),
          backgroundColor: AppColors.primary,
        ),
      );
      // Navigate to Respond & Navigate screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RespondNavigateScreen(alertId: detail.id),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }

  void _showDeclineDialog(
    BuildContext context,
    AlertDetail detail,
    AlertsProvider provider,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DeclineDialog(
        alertId: detail.id,
        currentStatus: detail.status,
        provider: provider,
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _AlertHeaderCard extends StatelessWidget {
  final AlertDetail detail;
  const _AlertHeaderCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.failedRed,
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'GEOFENCE BREACH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ThreatBadge(level: detail.threatLevel),
            ],
          ),
          const SizedBox(height: 8),
          StatusChip(status: detail.status),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final AlertDetail detail;
  const _InfoCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Uc02Constants.screenPadding),
        child: Column(
          children: [
            _row(Icons.cruelty_free_rounded, 'Animal',
                '${detail.animalName}${detail.animalTag != null ? "  ·  ${detail.animalTag}" : ""}'),
            if (detail.species != null)
              _row(Icons.info_outline_rounded, 'Species', detail.species!),
            if (detail.sex != null)
              _row(Icons.wc_rounded, 'Sex', detail.sex!),
            _row(Icons.place_rounded, 'Zone', detail.zoneName),
            if (detail.zoneType != null)
              _row(Icons.category_outlined, 'Zone type', detail.zoneType!),
            _row(Icons.access_time_rounded, 'Breach time',
                _formatBreachTime(detail.breachTime)),
            if (detail.distanceToRangerKm > 0) ...[
              _row(Icons.directions_car_rounded, 'Distance to you',
                  '${detail.distanceToRangerKm.toStringAsFixed(1)} km  ·  ~${detail.etaMinutes} min'),
            ],
            _row(Icons.home_work_rounded, 'Nearest village',
                '${detail.nearestVillageName}'
                '${detail.distanceToVillageM > 0 ? "  ·  ${(detail.distanceToVillageM / 1000).toStringAsFixed(1)} km away" : ""}'),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: Uc02Constants.minLabelFontSize,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: Uc02Constants.minBodyFontSize,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBreachTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SafetyCard extends StatelessWidget {
  final String instructions;
  const _SafetyCard({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Uc02Constants.screenPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
        border: Border.all(color: AppColors.pendingAmber),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_rounded, color: AppColors.pendingAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAFETY INSTRUCTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pendingAmber,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instructions,
                  style: const TextStyle(
                    fontSize: Uc02Constants.minBodyFontSize,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollarDetails extends StatelessWidget {
  final AlertDetail detail;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollarDetails({
    required this.detail,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.sensors_rounded, color: AppColors.primary),
            title: const Text(
              'Collar details',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Uc02Constants.minBodyFontSize),
            ),
            trailing: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            onTap: onToggle,
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Uc02Constants.screenPadding),
              child: Column(
                children: [
                  _collarRow('Code', detail.collarCode),
                  _collarRow('Battery', '${detail.collarBattery}%'),
                  _collarRow('Status', detail.collarStatus),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _collarRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: Uc02Constants.minLabelFontSize,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: Uc02Constants.minBodyFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenRespondButton extends StatelessWidget {
  final AlertDetail detail;
  const _OpenRespondButton({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: Uc02Constants.primaryButtonHeight,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RespondNavigateScreen(alertId: detail.id),
            ),
          ),
          icon: const Icon(Icons.directions_run_rounded),
          label: const Text(
            'VIEW RESPONSE DETAILS',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DeclineDialog extends StatefulWidget {
  final String alertId;
  final AlertStatus currentStatus;
  final AlertsProvider provider;

  const _DeclineDialog({
    required this.alertId,
    required this.currentStatus,
    required this.provider,
  });

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  String? _selectedReason;
  final _otherController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cannot Respond',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a reason:',
            style: TextStyle(fontSize: Uc02Constants.minBodyFontSize),
          ),
          const SizedBox(height: 8),
          ...Uc02Constants.declineReasons.map((reason) {
            return RadioListTile<String>(
              value: reason,
              groupValue: _selectedReason,
              title: Text(reason,
                  style: const TextStyle(
                      fontSize: Uc02Constants.minBodyFontSize)),
              onChanged: (v) => setState(() => _selectedReason = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
            );
          }),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _otherController,
              decoration: const InputDecoration(
                hintText: 'Describe the reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null || _isSubmitting
              ? null
              : () => _submit(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.failedRed,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Decline'),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() => _isSubmitting = true);
    final reason = _selectedReason == 'Other' && _otherController.text.isNotEmpty
        ? 'Other: ${_otherController.text.trim()}'
        : _selectedReason!;

    await widget.provider.performAction(
      alertId: widget.alertId,
      currentStatus: widget.currentStatus,
      type: ActionType.decline,
      payload: {'reason': reason},
    );

    if (context.mounted) {
      Navigator.pop(context); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Decline recorded. Alert will be reassigned to another ranger.'),
        ),
      );
    }
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.failedRed),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize:
                    const Size(double.infinity, Uc02Constants.primaryButtonHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
