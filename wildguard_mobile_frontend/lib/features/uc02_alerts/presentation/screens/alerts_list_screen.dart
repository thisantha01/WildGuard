import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/location_service.dart';
import '../../domain/entities/alert_summary.dart';
import '../../domain/enums/alert_status.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/status_chip.dart';
import '../widgets/threat_badge.dart';
import 'alert_detail_screen.dart';

/// Screen 1 — Alerts List (the "Alerts" tab).
///
/// Displays all alerts assigned to the logged-in ranger.
/// Auto-refreshes every 12 seconds while online.
/// Pull-to-refresh available at any time.
/// Shows cached data when offline with the [OfflineBanner].
class AlertsListScreen extends StatelessWidget {
  const AlertsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      Provider.of<AlertsProvider>(context, listen: false);
      return const _AlertsListScaffold();
    } catch (_) {
      return ChangeNotifierProvider<AlertsProvider>(
        create: (_) => buildAlertsProvider(
          tokenGetter: () => null,
          isOnlineGetter: () => false,
          connectivityService: ConnectivityService(),
          locationService: LocationService(),
        ),
        child: const _AlertsListScaffold(),
      );
    }
  }
}

class _AlertsListScaffold extends StatelessWidget {
  const _AlertsListScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: _AlertsListBody(),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Consumer<AlertsProvider>(
        builder: (context, provider, _) {
          return Row(
            children: [
              const Text('Geofence Alerts'),
              if (provider.pendingSyncCount > 0) ...[
                const SizedBox(width: 8),
                _PendingBadge(count: provider.pendingSyncCount),
              ],
            ],
          );
        },
      ),
      actions: [
        Consumer<AlertsProvider>(
          builder: (context, provider, _) => PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'sync') {
                await provider.syncNow();
                if (context.mounted && provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!)),
                  );
                  provider.clearError();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      color: provider.isSyncing ? Colors.grey : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(provider.isSyncing ? 'Syncing…' : 'Sync now'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertsListBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            OfflineBanner(isOnline: provider.isOnline),
            Expanded(
              child: _buildContent(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, AlertsProvider provider) {
    if (provider.listState == AlertsLoadState.loading &&
        provider.alerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.listState == AlertsLoadState.error &&
        provider.alerts.isEmpty) {
      return _ErrorState(
        message: provider.errorMessage ?? 'Unknown error',
        onRetry: () => provider.loadAlerts(),
      );
    }
    if (provider.alerts.isEmpty) {
      return _EmptyState(onRefresh: () => provider.loadAlerts());
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => provider.loadAlerts(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: Uc02Constants.screenPadding,
          vertical: Uc02Constants.screenPadding,
        ),
        itemCount: provider.alerts.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: Uc02Constants.minButtonSpacing),
        itemBuilder: (context, index) {
          final alert = provider.alerts[index];
          return _AlertCard(
            alert: alert,
            onTap: () => _openDetail(context, alert),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, AlertSummary alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(alertId: alert.id),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertSummary alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = alert.status == AlertStatus.notified ||
        alert.status == AlertStatus.acknowledged ||
        alert.status == AlertStatus.inProgress ||
        alert.status == AlertStatus.pendingResolution;

    return Semantics(
      button: true,
      label:
          'Alert ${alert.displayCode}: ${alert.animalName}, ${alert.threatLevel.displayLabel} threat, status ${alert.status.displayLabel}',
      child: Card(
        elevation: isActive ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
          side: BorderSide(
            color: isActive ? alert.threatLevel.badgeColor : AppColors.cardBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Uc02Constants.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(Uc02Constants.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.displayCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ThreatBadge(level: alert.threatLevel),
                  ],
                ),
                const SizedBox(height: 8),
                // Animal + tag
                Row(
                  children: [
                    const Icon(Icons.cruelty_free_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${alert.animalName}'
                        '${alert.animalTag != null ? "  ·  ${alert.animalTag}" : ""}',
                        style: const TextStyle(
                          fontSize: Uc02Constants.minBodyFontSize,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (alert.species != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.species!,
                    style: const TextStyle(
                      fontSize: Uc02Constants.minLabelFontSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Zone + time row
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${alert.zoneName}'
                        '${alert.zoneType != null ? "  (${alert.zoneType})" : ""}',
                        style: const TextStyle(
                          fontSize: Uc02Constants.minLabelFontSize,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(alert.breachTime),
                      style: const TextStyle(
                        fontSize: Uc02Constants.minLabelFontSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Status chip
                StatusChip(status: alert.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.pendingAmber,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count pending',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 72, color: AppColors.primaryLight),
          const SizedBox(height: 16),
          const Text(
            'No active alerts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your sector is clear. Pull down to refresh.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off_rounded,
                size: 64, color: AppColors.failedRed),
            const SizedBox(height: 16),
            const Text(
              'Could not load alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
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
