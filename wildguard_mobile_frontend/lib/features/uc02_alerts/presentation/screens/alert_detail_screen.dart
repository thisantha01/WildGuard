import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../viewmodels/auth_manager.dart';
import '../../domain/entities/alert_detail.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../../domain/enums/threat_level.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import '../widgets/alert_map_preview.dart';
import 'respond_navigate_screen.dart';

/// Screen 2 — Alert Detail (Screenshot 1).
///
/// Features:
///   - Top bar: "Wildlife Monitor / Sri Lanka DWC" & "Saman P / Unit R-07"
///   - Top gold offline notification bar
///   - Geofence Breach card with red banner, 2-column info grid, NOTIFIED badge
///   - Stylized map preview with "Full map" button
///   - Collapsible Collar details section
///   - Action buttons: ACKNOWLEDGE (ElevatedButton) and CANNOT RESPOND (OutlinedButton)
class AlertDetailScreen extends StatefulWidget {
  final String alertId;
  const AlertDetailScreen({super.key, required this.alertId});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  @override
  void initState() {
    super.initState();
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

        int pendingCount = 0;
        try {
          pendingCount = provider.pendingSyncCount;
        } catch (_) {}

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              children: [
                // ── Offline Bar across the top (Screenshot 1) ─────────────────
                if (!provider.isOnline || pendingCount > 0)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF59E0B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Text(
                      'OFFLINE - Alerts and actions are saved on this phone and will sync automatically',
                      style: TextStyle(
                        color: Color(0xFF451A03),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // ── Top Header Bar (Back button + Wildlife Monitor + Ranger) ──
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

                // ── Screen Body ───────────────────────────────────────────────
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.failedRed),
            const SizedBox(height: 12),
            Text(provider.errorMessage ?? 'Alert details unavailable'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadAlertDetail(widget.alertId),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Geofence Breach Card (Screenshot 1) ───────────────────────────
          _buildGeofenceCard(detail),
          const SizedBox(height: 14),

          // ── Map Preview Section with Full map button ─────────────────────
          _buildMapPreview(detail),
          const SizedBox(height: 14),

          // ── Collapsible Collar Details Card ──────────────────────────────
          _buildCollarCard(detail),
          const SizedBox(height: 14),

          // ── Safety Instructions Card (for test & field safety) ────────────
          if (detail.safetyInstructions.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: Color(0xFFF59E0B), width: 4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detail.safetyInstructions,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Action Buttons ───────────────────────────────────────────────
          _buildActionButtons(context, detail, provider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGeofenceCard(AlertDetail detail) {
    final isHigh = detail.threatLevel == ThreatLevel.high;
    final headerColor = isHigh ? const Color(0xFFC62828) : const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red Header Banner
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                const Text(
                  'GEOFENCE BREACH',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    detail.threatLevel.displayLabel.toUpperCase(),
                    style: TextStyle(
                      color: headerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animal Name + Tag + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Animal ',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            detail.animalName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            ' (${detail.animalTag ?? "ELE-024"})',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        detail.status.displayLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Species Subtitle + Display Code
                Row(
                  children: [
                    Text(
                      detail.species ?? 'Sri Lankan elephant',
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
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
                const SizedBox(height: 14),

                // 2-Column Info Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Zone'),
                          _fieldValue(detail.zoneType ?? 'FARMLAND'),
                          const SizedBox(height: 10),
                          _fieldLabel('Location'),
                          _fieldValue(detail.zoneName),
                          const SizedBox(height: 10),
                          _fieldLabel('Village'),
                          _fieldValue(detail.nearestVillageName.isNotEmpty ? detail.nearestVillageName : 'Ihatikulama'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Breach'),
                          _fieldValue(_formatTime(detail.breachTime)),
                          const SizedBox(height: 10),
                          _fieldLabel('Distance to you'),
                          _fieldValue('${detail.distanceToRangerKm.toStringAsFixed(1)} km (${detail.etaMinutes} min)'),
                          const SizedBox(height: 10),
                          _fieldLabel('From animal'),
                          _fieldValue('${detail.distanceToVillageM.toStringAsFixed(0)} m'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview(AlertDetail detail) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Map preview painter/widget
          Positioned.fill(
            child: AlertMapPreview(detail: detail),
          ),

          // "Full map" button (Screenshot 1)
          Positioned(
            right: 12,
            top: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0D6838), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fullscreen_rounded, color: Color(0xFF0D6838), size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Full map',
                    style: TextStyle(
                      color: Color(0xFF0D6838),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollarCard(AlertDetail detail) {
    final isCollarActive = detail.collarStatus.toUpperCase() == 'ACTIVE';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors_rounded, color: Color(0xFF0F172A), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Collar details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCollarActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  detail.collarStatus.toUpperCase(),
                  style: TextStyle(
                    color: isCollarActive ? const Color(0xFF166534) : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _collarRow('Collar Code', detail.collarCode),
          const SizedBox(height: 8),
          _collarRow('Battery', '${detail.collarBattery}%'),
          const SizedBox(height: 8),
          _collarRow('Collar Status', detail.collarStatus),
          const SizedBox(height: 8),
          _collarRow('GPS Coordinates', '${detail.lat.toStringAsFixed(4)}, ${detail.lng.toStringAsFixed(4)}'),
          const SizedBox(height: 8),
          _collarRow(
            'GPS Fix',
            detail.approximateLocation ? 'Approximate (Cell Tower)' : 'Accurate (GNSS Fix)',
          ),
        ],
      ),
    );
  }

  Widget _collarRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, AlertDetail detail, AlertsProvider provider) {
    // If the alert is resolved, remove continue to navigation button and display resolved indicator
    if (detail.status == AlertStatus.resolved) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF0D6838), size: 20),
            SizedBox(width: 8),
            Text(
              'ALERT RESOLVED',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (detail.status == AlertStatus.notified) {
      final isAcknowledgeInFlight = provider.isActionInFlight(detail.id, ActionType.acknowledge);
      final isDeclineInFlight = provider.isActionInFlight(detail.id, ActionType.decline);

      return Column(
        children: [
          // Primary ACKNOWLEDGE Button
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
              onPressed: isAcknowledgeInFlight ? null : () => _acknowledge(context, detail, provider),
              child: isAcknowledgeInFlight
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('ACKNOWLEDGE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary CANNOT RESPOND Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isDeclineInFlight ? null : () => _decline(context, detail, provider),
              child: const Text('CANNOT RESPOND', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    // If active and acknowledged/dispatched/on scene, show navigate button
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D6838),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => RespondNavigateScreen(alertId: detail.id)),
          );
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('CONTINUE TO NAVIGATION', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _acknowledge(BuildContext context, AlertDetail detail, AlertsProvider provider) async {
    final nextStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: detail.status,
      type: ActionType.acknowledge,
    );

    if (!context.mounted) return;
    if (nextStatus != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RespondNavigateScreen(alertId: detail.id)),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }

  Future<void> _decline(BuildContext context, AlertDetail detail, AlertsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Respond?'),
        content: const Text('This alert will be reassigned to the next available ranger in your sector.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('CONFIRM', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final next = await provider.performAction(
        alertId: detail.id,
        currentStatus: detail.status,
        type: ActionType.decline,
      );
      if (!context.mounted) return;
      if (next != null) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
    );
  }

  Widget _fieldValue(String text) {
    return Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)));
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
