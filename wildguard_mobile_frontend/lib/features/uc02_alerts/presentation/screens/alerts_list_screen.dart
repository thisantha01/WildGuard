import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/location_service.dart';
import '../../../../viewmodels/auth_manager.dart';
import '../../domain/entities/alert_summary.dart';
import '../../domain/enums/alert_status.dart';
import '../../domain/enums/threat_level.dart';
import '../constants/uc02_constants.dart';
import '../providers/alerts_provider.dart';
import 'alert_detail_screen.dart';

/// Screen 1 — Alerts List (the "Alerts" tab).
///
/// Designed precisely to match the Wildlife Monitor specification:
///   - Top Bar: "Wildlife Monitor / Sri Lanka DWC" & "Saman P / Unit R-07"
///   - Big header "Alerts"
///   - Segmented Pill switch: "Alerts" vs "Past reports"
///   - Filter dropdown pills
///   - Offline sync notice
///   - Geofence Breach card & Field Report card layouts
class AlertsListScreen extends StatelessWidget {
  const AlertsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AlertsProvider? alertsProvider;
    try {
      alertsProvider = Provider.of<AlertsProvider>(context, listen: false);
    } catch (_) {}

    if (alertsProvider == null) {
      return ChangeNotifierProvider<AlertsProvider>(
        create: (_) => buildAlertsProvider(
          tokenGetter: () => null,
          isOnlineGetter: () => false,
          connectivityService: ConnectivityService(),
          locationService: LocationService(),
        ),
        child: const _AlertsListView(),
      );
    }

    return const _AlertsListView();
  }
}

class _AlertsListView extends StatefulWidget {
  const _AlertsListView();

  @override
  State<_AlertsListView> createState() => _AlertsListViewState();
}

class _AlertsListViewState extends State<_AlertsListView> {
  int _selectedTab = 0; // 0: Alerts, 1: Past reports

  // Filter states for Alerts tab
  String _statusFilter = 'All';
  String _threatFilter = 'All';
  String _dateFilter = 'All';

  // Filter states for Past reports tab
  String _pastDateFilter = 'All';
  String _syncStatusFilter = 'All';
  String _moreFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<AlertsProvider>().loadAlerts();
        } catch (_) {}
      }
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
        int pendingCount = 0;
        try {
          pendingCount = provider.pendingSyncCount;
        } catch (_) {}
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.loadAlerts(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Top Header Bar ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              SizedBox(height: 2),
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
                              const SizedBox(height: 2),
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
                  ),

                  // ── Main Page Title ─────────────────────────────────────────
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  // ── Segmented Switcher (Alerts vs Past reports) ──────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SegmentPill(
                              label: 'Alerts',
                              selected: _selectedTab == 0,
                              onTap: () => setState(() => _selectedTab = 0),
                            ),
                          ),
                          Expanded(
                            child: _SegmentPill(
                              label: 'Past reports',
                              selected: _selectedTab == 1,
                              onTap: () => setState(() => _selectedTab = 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Filter Dropdown Pills Row ───────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _selectedTab == 0
                              ? [
                                  _FilterPill(
                                    label: 'Status',
                                    currentVal: _statusFilter,
                                    options: const [
                                      'All',
                                      'Pending Resolution',
                                      'In Progress',
                                      'Notified',
                                      'Acknowledged'
                                    ],
                                    onSelected: (v) => setState(() => _statusFilter = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterPill(
                                    label: 'Threat level',
                                    currentVal: _threatFilter,
                                    options: const ['All', 'High', 'Moderate', 'Low'],
                                    onSelected: (v) => setState(() => _threatFilter = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterPill(
                                    label: 'Date',
                                    currentVal: _dateFilter,
                                    options: const ['All', 'Today', 'Past 7 days'],
                                    onSelected: (v) => setState(() => _dateFilter = v),
                                  ),
                                ]
                              : [
                                  _FilterPill(
                                    label: 'Date',
                                    currentVal: _pastDateFilter,
                                    options: const ['All', 'Today', 'Past 7 days'],
                                    onSelected: (v) => setState(() => _pastDateFilter = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterPill(
                                    label: 'Sync status',
                                    currentVal: _syncStatusFilter,
                                    options: const ['All', 'Pending sync', 'Synced'],
                                    onSelected: (v) => setState(() => _syncStatusFilter = v),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterPill(
                                    label: 'More',
                                    currentVal: _moreFilter,
                                    options: const ['All', 'Safe only', 'With notes'],
                                    onSelected: (v) => setState(() => _moreFilter = v),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),

                  // ── Offline Banner Strip ────────────────────────────────────
                  if (!provider.isOnline || pendingCount > 0)
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Offline · Will sync automatically when online',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 6)),

                  // ── Cards List Content ──────────────────────────────────────
                  _buildListSliver(provider),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListSliver(AlertsProvider provider) {
    if (provider.listState == AlertsLoadState.loading && provider.alerts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (provider.listState == AlertsLoadState.error && provider.alerts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.signal_wifi_off_rounded, size: 54, color: AppColors.failedRed),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage ?? 'Could not load alerts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.loadAlerts(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Filter items according to the active tab & dropdowns
    final allAlerts = provider.alerts;
    final List<AlertSummary> items;

    if (_selectedTab == 0) {
      // "Alerts" Tab: Active alerts
      items = allAlerts.where((a) {
        if (_statusFilter != 'All') {
          if (a.status.displayLabel.toLowerCase() != _statusFilter.toLowerCase()) {
            return false;
          }
        }
        if (_threatFilter != 'All') {
          if (a.threatLevel.displayLabel.toLowerCase() != _threatFilter.toLowerCase()) {
            return false;
          }
        }
        if (_dateFilter == 'Today') {
          final now = DateTime.now();
          final local = a.breachTime.toLocal();
          if (local.year != now.year || local.month != now.month || local.day != now.day) {
            return false;
          }
        } else if (_dateFilter == 'Past 7 days') {
          if (DateTime.now().difference(a.breachTime).inDays > 7) return false;
        }
        return true;
      }).toList();
    } else {
      // "Past reports" Tab: Resolved or reports filed
      items = allAlerts.where((a) {
        // By default show resolved or pending resolution alerts
        final isReport = a.status == AlertStatus.resolved ||
            a.status == AlertStatus.pendingResolution;
        if (!isReport && allAlerts.any((x) => x.status == AlertStatus.resolved)) {
          return false;
        }
        if (_syncStatusFilter == 'Pending sync' && provider.isOnline) {
          return false;
        }
        return true;
      }).toList();
    }

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 54, color: AppColors.primaryLight),
                const SizedBox(height: 12),
                Text(
                  _selectedTab == 0 ? 'No alerts found' : 'No past reports',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sector is clear or no items match your filter.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final alert = items[index];
          if (_selectedTab == 0) {
            return _GeofenceBreachCard(
              alert: alert,
              onTap: () => _openDetail(context, alert),
            );
          } else {
            return _PastReportCard(
              alert: alert,
              isOnline: provider.isOnline,
              onTap: () => _openDetail(context, alert),
            );
          }
        },
        childCount: items.length,
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

// ── Segmented Switcher Pill Widget ───────────────────────────────────────────

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D6838) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

// ── Filter Dropdown Pill Widget ──────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final String currentVal;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _FilterPill({
    required this.label,
    required this.currentVal,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentVal != 'All';
    return PopupMenuButton<String>(
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => options.map((opt) {
        return PopupMenuItem(
          value: opt,
          child: Row(
            children: [
              if (opt == currentVal)
                const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0D6838))
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(
                opt,
                style: TextStyle(
                  fontWeight: opt == currentVal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF0D6838) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? '$label: $currentVal' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF0D6838) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: isActive ? const Color(0xFF0D6838) : const Color(0xFF0F172A),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card 1: Geofence Breach Card (Image 1) ───────────────────────────────────

class _GeofenceBreachCard extends StatelessWidget {
  final AlertSummary alert;
  final VoidCallback onTap;

  const _GeofenceBreachCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHigh = alert.threatLevel == ThreatLevel.high;
    final headerColor = isHigh ? const Color(0xFFC62828) : const Color(0xFFD97706);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // ── Red Banner ──────────────────────────────────────────────────
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
                    alert.threatLevel.displayLabel.toUpperCase(),
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

          // ── Card Body ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Display Code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        '${alert.animalName} (${alert.animalTag ?? "ELE-024"})',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert.displayCode,
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
                  alert.species ?? 'Sri Lankan elephant',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.status.displayLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2-Column Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Location'),
                          _fieldValue(alert.zoneName),
                          const SizedBox(height: 10),
                          _fieldLabel('Zone at breach'),
                          _fieldValue(alert.zoneType ?? 'FARMLAND'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Breach time'),
                          _fieldValue(_formatTime(alert.breachTime)),
                          const SizedBox(height: 10),
                          _fieldLabel('Village near animal'),
                          _fieldValue('Ihatikulama'),
                          const Text(
                            '600 m from animal',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // View Details Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6838),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onTap,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View alert details',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _fieldValue(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ── Card 2: Past Report Card (Image 2) ───────────────────────────────────────

class _PastReportCard extends StatelessWidget {
  final AlertSummary alert;
  final bool isOnline;
  final VoidCallback onTap;

  const _PastReportCard({
    required this.alert,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPendingSync = !isOnline || alert.status == AlertStatus.pendingResolution;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: "Field report" + Pill
          Row(
            children: [
              const Text(
                'Field report',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPendingSync ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPendingSync ? 'PENDING SYNC' : 'SYNCED',
                  style: TextStyle(
                    color: isPendingSync ? const Color(0xFF92400E) : const Color(0xFF065F46),
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Animal Name & Code
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${alert.animalName} (${alert.animalTag ?? "ELE-024"})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                alert.displayCode,
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
            alert.species ?? 'Sri Lankan elephant',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.zoneName,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Situation is safe Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Situation is safe',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No crop damage · No injuries',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Saved status
          Text(
            isPendingSync ? 'Saved on phone' : 'Synced to server',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isPendingSync
                ? 'Alert ${alert.displayCode} will be RESOLVED after sync.'
                : 'Alert ${alert.displayCode} is resolved and synced with server.',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // View Saved Report Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6838),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onTap,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View saved report',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
