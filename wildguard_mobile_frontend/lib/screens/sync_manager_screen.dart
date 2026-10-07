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

  void _onSyncAll(BuildContext context, OfflineSyncManager manager) async {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.syncDashboardTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload List',
            onPressed: () => manager.loadIncidents(),
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

          // Incident List
          Expanded(
            child: manager.isLoading
                ? const Center(child: CircularProgressIndicator())
                : manager.incidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              AppStrings.emptyIncidentListText,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => manager.loadIncidents(),
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
