import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../viewmodels/auth_manager.dart';
import '../../domain/entities/alert_detail.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import '../widgets/alert_map_preview.dart';
import 'field_report_screen.dart';

/// Screen 3 — Respond & Navigate (Screenshots 2 and 3).
///
/// Features:
///   - Top bar: "Wildlife Monitor / Sri Lanka DWC" & "Saman P / Unit R-07"
///   - Title "Respond & navigate" with status pill (ACKNOWLEDGED / IN PROGRESS)
///   - Stepper: Acknowledged › Dispatched › On scene
///   - Mini-map preview card with ETA & distances line
///   - Safety standoff warning card (Keep 100 m distance...)
///   - If ACKNOWLEDGED: "CONFIRM DISPATCH" button + 3 quick buttons + outlined "ARRIVED ON SCENE"
///   - If IN PROGRESS: "Dispatch confirmed" card + 3 quick buttons + solid green "ARRIVED ON SCENE"
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
    AuthManager? authManager;
    try {
      authManager = Provider.of<AuthManager>(context, listen: false);
    } catch (_) {}
    final user = authManager?.currentUser;
    final rangerName = (user?.fullName.isNotEmpty == true) ? user!.fullName : 'Saman P';
    final unitCode = (user?.badgeNumber?.isNotEmpty == true)
        ? (user!.badgeNumber!.startsWith('Unit') ? user.badgeNumber! : 'Unit ${user.badgeNumber}')
        : 'Unit R-07';

    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        final detail = provider.currentDetail;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Header Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Wildlife Monitor',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Sri Lanka DWC',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rangerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            unitCode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Screen Content ──────────────────────────────────────────
                Expanded(child: _buildBody(context, provider, detail)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AlertsProvider provider, AlertDetail? detail) {
    if (provider.detailState == AlertsLoadState.loading && detail == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (detail == null) {
      return const Center(child: Text('Alert not available.'));
    }

    final isDispatched = detail.status == AlertStatus.inProgress ||
        detail.status == AlertStatus.pendingResolution ||
        detail.status == AlertStatus.resolved;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Row: "Respond & navigate" + Status Pill ────────────────
          Row(
            children: [
              const Text(
                'Respond & navigate',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDispatched ? 'IN PROGRESS' : 'ACKNOWLEDGED',
                  style: const TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Animal Name + Code
          Row(
            children: [
              Text(
                '${detail.animalName} (${detail.animalTag ?? "ELE-024"})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                detail.displayCode,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${detail.species ?? "Sri Lankan elephant"} · ${detail.zoneName}',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // ── Breadcrumb Stepper ──────────────────────────────────────────
          _buildStepper(isDispatched),
          const SizedBox(height: 14),

          // ── Map & Route Card ────────────────────────────────────────────
          _buildMapCard(detail),
          const SizedBox(height: 14),

          // ── Safety Standoff Warning Box ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail.safetyInstructions.isNotEmpty
                        ? detail.safetyInstructions
                        : 'Keep 100 m distance - Use loudspeaker - Do not approach directly',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Dispatch Status or Confirm Dispatch Button ──────────────────
          if (!isDispatched)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6838),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _confirmDispatch(context, detail, provider),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.near_me_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CONFIRM DISPATCH',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_rounded, color: Color(0xFF0D6838), size: 22),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispatch confirmed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D6838),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Follow the route to Rajah.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // ── Quick Action Buttons Row (Call Base, Call CLO, Camera) ───────
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.sensors_rounded,
                  label: 'Call Base',
                  onTap: () => _callNumber(context, '1990'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call CLO',
                  onTap: () => _callNumber(context, '0771234567'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () => _openCamera(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Arrived on Scene Button ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isDispatched
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6838),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _arrivedOnScene(context, detail, provider),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ARRIVED ON SCENE',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D6838),
                      side: const BorderSide(color: Color(0xFF0D6838), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _arrivedOnScene(context, detail, provider),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ARRIVED ON SCENE',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStepper(bool isDispatched) {
    return Row(
      children: [
        _stepDot(true, 'Acknowledged'),
        const SizedBox(width: 6),
        const Text('›', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
        const SizedBox(width: 6),
        _stepDot(isDispatched, 'Dispatched'),
        const SizedBox(width: 6),
        const Text('›', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
        const SizedBox(width: 6),
        _stepDot(false, 'On scene'),
      ],
    );
  }

  Widget _stepDot(bool active, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 8,
          color: active ? const Color(0xFF0D6838) : const Color(0xFFCBD5E1),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? const Color(0xFF0D6838) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMapCard(AlertDetail detail) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: AlertMapPreview(detail: detail),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              '${detail.animalName} to village ${detail.distanceToVillageM.toStringAsFixed(0)} m - '
              'You to ${detail.animalName} ${detail.distanceToRangerKm.toStringAsFixed(1)} km - '
              'ETA ${detail.etaMinutes} min',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDispatch(
      BuildContext context, AlertDetail detail, AlertsProvider provider) async {
    final nextStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: detail.status,
      type: ActionType.confirmDispatch,
    );
    if (!context.mounted) return;
    if (nextStatus != null) {
      provider.loadAlertDetail(detail.id);
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }

  Future<void> _arrivedOnScene(
      BuildContext context, AlertDetail detail, AlertsProvider provider) async {
    final nextStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: detail.status,
      type: ActionType.arrived,
    );
    if (!context.mounted) return;
    if (nextStatus != null || detail.status == AlertStatus.pendingResolution) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FieldReportScreen(
            alertId: detail.id,
            capturedPhotoPath: _capturedPhotoPath,
          ),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }

  Future<void> _callNumber(BuildContext context, String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot call $number')));
      }
    } catch (_) {}
  }

  Future<void> _openCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _capturedPhotoPath = photo.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo attached for field report.')));
        }
      }
    } catch (_) {}
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF0D6838), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
