import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../models/sync_status.dart';
import '../viewmodels/auth_manager.dart';
import '../viewmodels/offline_sync_manager.dart';
import '../widgets/incident_card_widget.dart';
import 'log_incident_screen.dart';
import 'login_screen.dart';
import 'sync_manager_screen.dart';

/// Patrol Dashboard Screen for Park Ranger (ROLE_RANGER).
/// Serves as the mission-critical field operations hub for active patrol shifts,
/// surfacing real-time telemetry, offline synchronization queues, and high-priority actions.
class PatrolDashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const PatrolDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<PatrolDashboardScreen> createState() => _PatrolDashboardScreenState();
}

class _PatrolDashboardScreenState extends State<PatrolDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncManager = context.read<OfflineSyncManager>();
      syncManager.loadIncidents(fetchRemote: true);
      if (syncManager.latitude == null && !syncManager.isGpsLost) {
        syncManager.fetchLocation();
      }
    });
  }

  void _navigateToLogIncident(BuildContext context) {
    context.read<OfflineSyncManager>().fetchLocation();
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LogIncidentScreen()),
      );
    }
  }

  void _navigateToSyncManager(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SyncManagerScreen()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final authManager = context.watch<AuthManager>();
    final syncManager = context.watch<OfflineSyncManager>();
    final user = authManager.currentUser;
    final isGuest = authManager.isOfflineGuestMode;

    final rangerName = isGuest ? 'Field Patrol Unit' : (user?.fullName.isNotEmpty == true ? user!.fullName : 'Field Ranger');
    final badgeId = user?.badgeNumber ?? (isGuest ? 'WG-RNG-OFFLINE' : 'WG-RNG-001');
    final assignedPark = user?.assignedPark ?? 'Yala National Park';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          AppStrings.patrolDashboardTitle,
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Patrol Data',
            onPressed: () {
              syncManager.loadIncidents(fetchRemote: true);
              syncManager.fetchLocation();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Patrol telemetry & incident records refreshed.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              authManager.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await syncManager.loadIncidents();
          await syncManager.fetchLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Ranger Identity & Deployment Card
              _buildRangerIdentityCard(
                rangerName: rangerName,
                badgeId: badgeId,
                assignedPark: assignedPark,
                isGuest: isGuest,
              ),

              const SizedBox(height: 16),

              // 2. Mission Telemetry / KPI Summary (4 Cards)
              _buildTelemetryGrid(syncManager),

              const SizedBox(height: 16),

              // 3. Fitts's Law Primary Rapid-Action Buttons
              _buildRapidActions(context, syncManager),

              const SizedBox(height: 16),

              // 4. Quick Field Patrol Utilities Row
              _buildPatrolUtilitiesRow(context, syncManager),

              const SizedBox(height: 20),

              // 5. Recent Field Logs / Shift Incident Feed
              _buildRecentIncidentsSection(context, syncManager),

              const SizedBox(height: 16),

              // 6. Emergency Dispatch Protocol Strip
              _buildEmergencyStrip(),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Identity & Sector Card with dynamic connectivity status pill.
  Widget _buildRangerIdentityCard({
    required String rangerName,
    required String badgeId,
    required String assignedPark,
    required bool isGuest,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rangerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ROLE_RANGER',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sector info
              Row(
                children: [
                  const Icon(Icons.park_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    assignedPark,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Connection status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isGuest
                      ? AppColors.pendingAmber.withValues(alpha: 0.9)
                      : AppColors.syncedGreen.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGuest ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGuest ? 'No Internet Connection' : 'Online (Connected)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Telemetry and KPI metric cards in a 2x2 grid.
  Widget _buildTelemetryGrid(OfflineSyncManager syncManager) {
    final gpsText = syncManager.latitude != null
        ? '${syncManager.latitude!.toStringAsFixed(3)}, ${syncManager.longitude!.toStringAsFixed(3)}'
        : (syncManager.isGpsLost ? 'GPS Lost' : 'Acquiring Fix...');

    return Row(
      children: [
        // Left Column (Pending Sync & GPS Fix)
        Expanded(
          child: Column(
            children: [
              _buildKpiCard(
                title: 'Pending Sync',
                value: '${syncManager.pendingCount}',
                subtitle: syncManager.pendingCount > 0 ? 'Requires base sync' : 'All clear',
                icon: Icons.cloud_upload_outlined,
                accentColor: syncManager.pendingCount > 0 ? AppColors.pendingAmber : AppColors.syncedGreen,
                onTap: () => _navigateToSyncManager(context),
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Current Location',
                value: gpsText,
                subtitle: syncManager.isGpsLost ? 'Tap to acquire' : 'Fixed Signal',
                icon: Icons.gps_fixed_rounded,
                accentColor: syncManager.isGpsLost ? AppColors.offlineBannerRed : AppColors.primary,
                onTap: () => syncManager.fetchLocation(),
                isSmallValue: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right Column (Synced Count & Total Incidents)
        Expanded(
          child: Column(
            children: [
              _buildKpiCard(
                title: 'Synced to Base',
                value: '${syncManager.syncedCount}',
                subtitle: 'Confirmed records',
                icon: Icons.cloud_done_rounded,
                accentColor: AppColors.syncedGreen,
                onTap: () => _navigateToSyncManager(context),
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Total Logged',
                value: '${syncManager.incidents.length}',
                subtitle: 'Local SQLite DB',
                icon: Icons.storage_rounded,
                accentColor: Colors.blueGrey,
                onTap: null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback? onTap,
    bool isSmallValue = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(icon, color: accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallValue ? 13 : 22,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Massive Fitts's Law rapid response buttons.
  Widget _buildRapidActions(BuildContext context, OfflineSyncManager syncManager) {
    return Column(
      children: [
        // Primary Action: [ 🚨 LOG FIELD INCIDENT ]
        ElevatedButton(
          key: const Key('patrol_log_incident_button'),
          onPressed: () => _navigateToLogIncident(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_location_alt_rounded, size: 26),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.quickLogIncident,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Record snare, poaching track, carcass, or alert',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Secondary Action: [ 🔄 VIEW SYNC QUEUE ]
        OutlinedButton(
          key: const Key('patrol_view_sync_button'),
          onPressed: () => _navigateToSyncManager(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.primary, width: 1.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sync_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                AppStrings.quickSyncQueue,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              if (syncManager.pendingCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.pendingAmber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${syncManager.pendingCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 4. Quick field tools (GPS, Fallback Pin, Radio VHF channel).
  Widget _buildPatrolUtilitiesRow(BuildContext context, OfflineSyncManager syncManager) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('patrol_gps_fix_button'),
            icon: const Icon(Icons.my_location, size: 16),
            label: const Text('Acquire GPS', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: () async {
              await syncManager.fetchLocation();
              if (context.mounted) {
                final status = syncManager.latitude != null
                    ? 'GPS Acquired: ${syncManager.latitude!.toStringAsFixed(4)}, ${syncManager.longitude!.toStringAsFixed(4)}'
                    : 'GPS Lost. Check open sky or drop manual pin.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(status),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('patrol_fallback_pin_button'),
            icon: const Icon(Icons.pin_drop_outlined, size: 16),
            label: const Text('Reserve Pin', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: () {
              syncManager.dropPinOnOfflineMap();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Yala National Park fallback pin pinned successfully.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 5. Recent Field Logs / Shift Incident Feed.
  Widget _buildRecentIncidentsSection(BuildContext context, OfflineSyncManager syncManager) {
    final recentIncidents = syncManager.incidents.reversed.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Recent Field Logs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${syncManager.incidents.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (syncManager.incidents.isNotEmpty)
              TextButton(
                onPressed: () => _navigateToSyncManager(context),
                child: const Text('View All', style: TextStyle(fontSize: 13, color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentIncidents.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.verified_user_outlined, size: 48, color: Colors.green.shade600),
                  const SizedBox(height: 10),
                  const Text(
                    'Patrol Sector All-Clear',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No field incidents recorded today on this patrol shift.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...recentIncidents.map((incident) => IncidentCardWidget(incident: incident)),
      ],
    );
  }

  /// 6. Emergency VHF strip adhering to Ranger SOPs.
  Widget _buildEmergencyStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.offlineBannerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: AppColors.offlineBannerRed.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.offlineBannerRed, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'EMERGENCY PROTOCOL: If armed poachers or trapped elephant detected, relay immediately via Base VHF CH-4.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.offlineBannerRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
