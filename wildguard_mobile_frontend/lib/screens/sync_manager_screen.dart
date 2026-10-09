import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../viewmodels/auth_manager.dart';
import '../viewmodels/offline_sync_manager.dart';
import '../widgets/incident_card_widget.dart';
import 'login_screen.dart';

/// Feature 2: The "Sync Manager" Screen showing saved incidents, color psychology tags, and sync button.
class SyncManagerScreen extends StatelessWidget {
  const SyncManagerScreen({super.key});

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Ranger Login Required'),
          ],
        ),
        content: const Text(
          'Base station synchronization requires Ranger authorization. Please log in with your Ranger credentials (e.g. ranger1 / Password@123) to upload pending reports to the central server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.login),
            label: const Text('Log In Now'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onSyncAll(BuildContext context, OfflineSyncManager manager) async {
    final authManager = context.read<AuthManager>();
    if (!authManager.isAuthenticated || authManager.isOfflineGuestMode || authManager.token == null) {
      _showLoginRequiredDialog(context);
      return;
    }

    final count = await manager.syncPendingIncidents();
    if (!context.mounted) return;

    final msg = manager.errorMessage ?? manager.successMessage ?? 'Synced $count incident(s).';
    final isError = manager.errorMessage != null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded : Icons.cloud_done_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.failedRed : AppColors.syncedGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<OfflineSyncManager>();
    final authManager = context.watch<AuthManager>();
    final isUnauthenticated = !authManager.isAuthenticated ||
        authManager.isOfflineGuestMode ||
        authManager.token == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.syncDashboardTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync with Server',
            onPressed: () async {
              await manager.loadIncidents(fetchRemote: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      manager.incidents.isEmpty
                          ? 'No reports found. If you submitted reports earlier, please verify you are logged in.'
                          : 'Synchronized ${manager.incidents.length} incident record(s).',
                    ),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              context.read<AuthManager>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Dashboard Counters Header (Color Psychology metrics)
          Container(
            padding: const EdgeInsets.all(AppConstants.standardPadding),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                _buildMetricCard(
                  label: 'Pending Sync',
                  count: manager.pendingCount,
                  color: AppColors.pendingAmber,
                  icon: Icons.pending_actions_rounded,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  label: 'Synced',
                  count: manager.syncedCount,
                  color: AppColors.syncedGreen,
                  icon: Icons.cloud_done_rounded,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  label: 'Total Logged',
                  count: manager.incidents.length,
                  color: AppColors.primary,
                  icon: Icons.list_alt_rounded,
                ),
              ],
            ),
          ),

          if (isUnauthenticated)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(color: const Color(0xFFFFEEBA), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF856404), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Offline Field Mode active. Log in to sync records with Base Station.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF856404),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('LOG IN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Incident List
          Expanded(
            child: manager.isLoading
                ? const Center(child: CircularProgressIndicator())
                : manager.incidents.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                isUnauthenticated
                                    ? 'No incidents recorded on this device yet.\nLog in to fetch your reports from the base station.'
                                    : 'No incidents recorded on this device yet.\nReports synced as "${authManager.currentUser?.username ?? 'unknown'}" will appear here.',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: manager.isLoading
                                    ? null
                                    : () async {
                                        final beforeCount = manager.incidents.length;
                                        await manager.loadIncidents(fetchRemote: true);
                                        if (!context.mounted) return;
                                        final afterCount = manager.incidents.length;
                                        final fetched = afterCount - beforeCount;
                                        final username = authManager.currentUser?.username ?? 'unknown';
                                        if (afterCount == 0) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isUnauthenticated
                                                    ? 'Please log in first to fetch your reports.'
                                                    : 'No reports found for "$username" on the base station server.',
                                              ),
                                              duration: const Duration(seconds: 3),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        } else if (fetched > 0) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Restored $fetched report(s) for "$username" from base station.'),
                                              backgroundColor: AppColors.syncedGreen,
                                              duration: const Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: const Text('Fetch My Reports from Base Station'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => manager.loadIncidents(fetchRemote: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          itemCount: manager.incidents.length,
                          itemBuilder: (context, index) {
                            final incident = manager.incidents[index];
                            return IncidentCardWidget(incident: incident);
                          },
                        ),
                      ),
          ),

          // Primary Bottom Action Button: [ 🔄 SYNC ALL PENDING ]
          Padding(
            padding: const EdgeInsets.all(AppConstants.standardPadding),
            child: ElevatedButton(
              key: const Key('sync_all_pending_button'),
              onPressed: manager.isSyncing ? null : () => _onSyncAll(context, manager),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, AppConstants.largeTouchTargetHeight),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
              child: manager.isSyncing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'SYNCHRONIZING WITH SERVER...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : const Text(
                      AppStrings.syncAllPendingButtonText,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
