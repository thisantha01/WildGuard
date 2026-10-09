import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/alert_detail.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import '../widgets/alert_map_preview.dart';
import '../widgets/offline_banner.dart';
import '../widgets/status_chip.dart';
import 'field_report_screen.dart';

/// Screen 3 — Respond & Navigate (wireframes 2 and 3 combined in one screen).
///
/// State ACKNOWLEDGED: shows "CONFIRM DISPATCH" + 3 utility buttons.
/// State IN_PROGRESS:  shows "ARRIVED ON SCENE" + 3 utility buttons.
/// Both states share the stepper, compact map, and summary line.
class RespondNavigateScreen extends StatefulWidget {
  final String alertId;
  final String? capturedPhotoPath;

  const RespondNavigateScreen({
    super.key,
    required this.alertId,
    this.capturedPhotoPath,
  });

  @override
  State<RespondNavigateScreen> createState() => _RespondNavigateScreenState();
}

class _RespondNavigateScreenState extends State<RespondNavigateScreen> {
  String? _capturedPhotoPath;
  bool _dispatchConfirmed = false; // local flag to show confirmation box

  @override
  void initState() {
    super.initState();
    _capturedPhotoPath = widget.capturedPhotoPath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().loadAlertDetail(widget.alertId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        final detail = provider.currentDetail;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text(detail?.displayCode ?? 'Responding'),
          ),
          body: Column(
            children: [
              OfflineBanner(isOnline: provider.isOnline),
              Expanded(
                child: _buildBody(context, provider, detail),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, AlertsProvider provider, AlertDetail? detail) {
    if (provider.detailState == AlertsLoadState.loading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (detail == null) {
      return const Center(child: Text('Alert not available.'));
    }

    // If alert moved to PENDING_RESOLUTION or RESOLVED, navigate away
    if (detail.status == AlertStatus.pendingResolution ||
        detail.status == AlertStatus.resolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && detail.status == AlertStatus.pendingResolution) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => FieldReportScreen(
                alertId: detail.id,
                capturedPhotoPath: _capturedPhotoPath,
              ),
            ),
          );
        }
      });
    }

    final stepIndex = _stepIndex(detail.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Uc02Constants.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status chip ────────────────────────────────────────────────
          Row(
            children: [
              StatusChip(status: detail.status),
            ],
          ),
          const SizedBox(height: 16),

          // ── Stepper ────────────────────────────────────────────────────
          _StepperRow(activeStep: stepIndex),
          const SizedBox(height: 16),

          // ── Compact map ────────────────────────────────────────────────
          AlertMapPreview(detail: detail),
          const SizedBox(height: 16),

          // ── Summary line ───────────────────────────────────────────────
          _SummaryLine(detail: detail),
          const SizedBox(height: 16),

          // ── Safety card ────────────────────────────────────────────────
          _SafetyCard(instructions: detail.safetyInstructions),
          const SizedBox(height: 16),

          // ── Dispatch confirmation box (shown after confirming dispatch) ─
          if (_dispatchConfirmed)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.syncedGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
                border: Border.all(color: AppColors.syncedGreen),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.syncedGreen),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dispatch confirmed. Follow the route to the breach location.',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          // ── Offline notice ─────────────────────────────────────────────
          if (!provider.isOnline)
            _OfflinePendingNotice(),

          // ── 3 large utility buttons ────────────────────────────────────
          _UtilityButtonsRow(
            detail: detail,
            onCamera: () => _pickPhoto(context),
          ),
          const SizedBox(height: 16),

          // ── Primary action ─────────────────────────────────────────────
          _PrimaryActionButton(
            detail: detail,
            provider: provider,
            onDispatchConfirmed: () => setState(() => _dispatchConfirmed = true),
            onArrived: () => _onArrived(context, detail, provider),
            capturedPhotoPath: _capturedPhotoPath,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  int _stepIndex(AlertStatus status) {
    switch (status) {
      case AlertStatus.acknowledged:
        return 0;
      case AlertStatus.inProgress:
        return 1;
      case AlertStatus.pendingResolution:
        return 2;
      default:
        return 0;
    }
  }

  Future<void> _pickPhoto(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        setState(() => _capturedPhotoPath = image.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured — it will be included in your field report.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera: $e')),
        );
      }
    }
  }

  Future<void> _onArrived(
    BuildContext context,
    AlertDetail detail,
    AlertsProvider provider,
  ) async {
    final newStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: detail.status,
      type: ActionType.arrived,
    );
    if (!context.mounted) return;
    if (newStatus != null) {
      // Navigate to Field Report
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FieldReportScreen(
            alertId: detail.id,
            capturedPhotoPath: _capturedPhotoPath,
          ),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StepperRow extends StatelessWidget {
  final int activeStep;
  const _StepperRow({required this.activeStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Uc02Constants.stepperLabels.asMap().entries.map((entry) {
        final idx = entry.key;
        final label = entry.value;
        final active = idx <= activeStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          active ? AppColors.primary : AppColors.cardBorder,
                      child: Icon(
                        active ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < Uc02Constants.stepperLabels.length - 1)
                Container(
                  height: 2,
                  width: 20,
                  color: idx < activeStep ? AppColors.primary : AppColors.cardBorder,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final AlertDetail detail;
  const _SummaryLine({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        'Animal → village: ${(detail.distanceToVillageM / 1000).toStringAsFixed(1)} km  '
        '·  You → animal: ${detail.distanceToRangerKm.toStringAsFixed(1)} km  '
        '·  ETA: ~${detail.etaMinutes} min',
        style: const TextStyle(
          fontSize: Uc02Constants.minBodyFontSize,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  final String instructions;
  const _SafetyCard({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
        border: Border.all(color: AppColors.pendingAmber),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_rounded, color: AppColors.pendingAmber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instructions,
              style: const TextStyle(
                fontSize: Uc02Constants.minBodyFontSize,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityButtonsRow extends StatelessWidget {
  final AlertDetail detail;
  final VoidCallback onCamera;

  const _UtilityButtonsRow({required this.detail, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _UtilityButton(
          icon: Icons.radio_rounded,
          label: 'Call Base',
          semanticLabel: 'Call base station',
          onTap: () => _callNumber(context, null, Uc02Constants.baseCallNotConfigured),
        ),
        const SizedBox(width: Uc02Constants.minButtonSpacing),
        _UtilityButton(
          icon: Icons.support_agent_rounded,
          label: 'Call CLO',
          semanticLabel: 'Call Community Liaison Officer',
          onTap: () => _callNumber(context, null, Uc02Constants.cloCallNotConfigured),
        ),
        const SizedBox(width: Uc02Constants.minButtonSpacing),
        _UtilityButton(
          icon: Icons.camera_alt_rounded,
          label: 'Camera',
          semanticLabel: 'Take a photo for the field report',
          onTap: onCamera,
        ),
      ],
    );
  }

  Future<void> _callNumber(
    BuildContext context,
    String? number,
    String fallbackMessage,
  ) async {
    if (number == null || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialler.')),
        );
      }
    }
  }
}

class _UtilityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _UtilityButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
          child: Container(
            height: Uc02Constants.iconButtonSize,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
              border: Border.all(color: AppColors.cardBorder, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final AlertDetail detail;
  final AlertsProvider provider;
  final VoidCallback onDispatchConfirmed;
  final VoidCallback onArrived;
  final String? capturedPhotoPath;

  const _PrimaryActionButton({
    required this.detail,
    required this.provider,
    required this.onDispatchConfirmed,
    required this.onArrived,
    this.capturedPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    if (detail.status == AlertStatus.acknowledged) {
      final inFlight =
          provider.isActionInFlight(detail.id, ActionType.confirmDispatch);
      return SizedBox(
        width: double.infinity,
        height: Uc02Constants.primaryButtonHeight,
        child: ElevatedButton.icon(
          onPressed: inFlight
              ? null
              : () => _confirmDispatch(context),
          icon: inFlight
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.local_shipping_rounded),
          label: const Text(
            'CONFIRM DISPATCH',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (detail.status == AlertStatus.inProgress) {
      final inFlight =
          provider.isActionInFlight(detail.id, ActionType.arrived);
      return SizedBox(
        width: double.infinity,
        height: Uc02Constants.primaryButtonHeight,
        child: ElevatedButton.icon(
          onPressed: inFlight ? null : onArrived,
          icon: inFlight
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.location_on_rounded),
          label: const Text(
            'ARRIVED ON SCENE',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    // Greyed out for other statuses
    return SizedBox(
      width: double.infinity,
      height: Uc02Constants.primaryButtonHeight,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.grey.shade600,
        ),
        child: Text(
          detail.status == AlertStatus.pendingResolution
              ? 'AWAITING FIELD REPORT'
              : 'NO ACTION AVAILABLE',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Future<void> _confirmDispatch(BuildContext context) async {
    final newStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: detail.status,
      type: ActionType.confirmDispatch,
    );
    if (!context.mounted) return;
    if (newStatus != null) {
      onDispatchConfirmed();
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }
}

class _OfflinePendingNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.pendingAmber.withValues(alpha: 0.12),
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
    );
  }
}
