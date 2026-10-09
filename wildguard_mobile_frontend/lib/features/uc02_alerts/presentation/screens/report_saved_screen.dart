import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../viewmodels/auth_manager.dart';
import '../../domain/enums/crop_damage.dart';
import '../../domain/enums/injury_severity.dart';
import '../providers/alerts_provider.dart';

/// Screen 5 — Report Saved / Confirmation (Screenshot 5).
///
/// Features:
///   - Top bar: "Wildlife Monitor / Sri Lanka DWC" & "Saman P / Unit R-07"
///   - Title "Field report & resolution"
///   - Animal info line
///   - Status badge & zone condition
///   - Big white card with soft green circle & checkmark
///   - "Report saved." message
///   - Damage & safety summary pill
///   - Offline sync notice
///   - "Back to Alerts" button
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
        final animalName = detail?.animalName ?? 'Rajah';
        final animalTag = detail?.animalTag ?? 'ELE-024';
        final species = detail?.species ?? 'Sri Lankan elephant';
        final zone = detail?.zoneName ?? 'Yala Sector 04';

        final damageText = cropDamage == CropDamage.none ? 'No crop damage' : '${cropDamage.displayLabel} crop damage';
        final injuryText = injuries == InjurySeverity.none ? 'No injuries' : '${injuries.displayLabel} injury';

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: SafeArea(
              child: Column(
                children: [
                  // ── Top Header Bar ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
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

                  // ── Screen Content ────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          const Text(
                            'Field report & resolution',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Animal Info Line
                          Row(
                            children: [
                              Text(
                                '$animalName ($animalTag)',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                displayCode,
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
                            '$species · $zone',
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),

                          // Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PENDING RESOLUTION',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            '$animalName has stayed outside the farmland zone (3 readings)',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ── Success Card (Screenshot 5) ───────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Circular Green Checkmark
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8F5E9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 46,
                                    color: Color(0xFF0D6838),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                const Text(
                                  'Report saved.',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Text(
                                  provider.isOnline
                                      ? 'Alert $displayCode has been RESOLVED'
                                      : 'Alert $displayCode will be RESOLVED after sync',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Summary Box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$damageText · $injuryText',
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Situation is safe',
                                        style: TextStyle(
                                          color: Color(0xFF0D6838),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Offline Strip ─────────────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.wifi_off_rounded, color: Color(0xFF92400E), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Saved on phone - will sync automatically',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Back to Alerts Button ─────────────────────────
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
                              onPressed: () {
                                provider.loadAlerts();
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              child: const Text(
                                'Back to Alerts',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
