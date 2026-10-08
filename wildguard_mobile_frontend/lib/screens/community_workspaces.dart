import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/community_alert_post.dart';
import '../models/community_conflict_report.dart';
import '../viewmodels/auth_manager.dart';
import '../viewmodels/community_conflict_manager.dart';
import 'login_screen.dart';

void _logout(BuildContext context) {
  context.read<AuthManager>().logout();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

void _profile(BuildContext context) {
  final a = context.read<AuthManager>();
  showDialog(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('WildGuard Profile'),
      content: Text(
        'Name: ${a.rangerDisplayName}\nRole: ${a.currentUser?.role ?? 'Offline'}\nEmail: ${a.currentUser?.email ?? ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    ),
  );
}

void _snackFrom(ScaffoldMessengerState messenger, String message) =>
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
Widget _card({required Widget child}) => Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
    side: const BorderSide(color: AppColors.cardBorder),
  ),
  child: Padding(
    padding: const EdgeInsets.all(AppConstants.standardPadding),
    child: child,
  ),
);

class VillagerCommunityDashboard extends StatefulWidget {
  const VillagerCommunityDashboard({super.key});
  @override
  State<VillagerCommunityDashboard> createState() =>
      _VillagerCommunityDashboardState();
}

class _VillagerCommunityDashboardState
    extends State<VillagerCommunityDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommunityConflictManager>().refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<CommunityConflictManager>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Safety'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: m.isLoading ? null : () => m.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh alerts and reports',
          ),
          IconButton(
            onPressed: () => _profile(context),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile and logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: m.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'OFFICIAL COMMUNITY ALERTS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (m.alerts.isEmpty)
              _card(
                child: const Text(
                  'No published safety alerts. Pull down to refresh.',
                ),
              ),
            ...m.alerts.map((a) => _AlertCard(alert: a)),
            const SizedBox(height: 20),
            const Text(
              'MY SUBMITTED INCIDENT REPORTS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (m.reports.isEmpty)
              _card(
                child: const Text(
                  'Your incident reports and their status will appear here.',
                ),
              ),
            ...m.reports.map((r) => _ReportCard(report: r, villager: true)),
          ],
        ),
      ),
    );
  }
}

class LiaisonOfficerDashboardScreen extends StatefulWidget {
  const LiaisonOfficerDashboardScreen({super.key});
  @override
  State<LiaisonOfficerDashboardScreen> createState() =>
      _LiaisonOfficerDashboardScreenState();
}

class _LiaisonOfficerDashboardScreenState
    extends State<LiaisonOfficerDashboardScreen> {
  String filter = 'All';
  final filters = [
    'All',
    'Unverified',
    'Verified',
    'In Progress',
    'Critical',
    'Resolved',
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommunityConflictManager>().refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<CommunityConflictManager>();
    final rows = m.reports
        .where(
          (r) => switch (filter) {
            'Unverified' =>
              r.status == ConflictReportStatus.unverified ||
                  r.status == ConflictReportStatus.pendingSync,
            'Verified' => r.status == ConflictReportStatus.verified,
            'In Progress' => r.status == ConflictReportStatus.inProgress,
            'Critical' => r.severity == ThreatSeverity.critical,
            'Resolved' => r.status == ConflictReportStatus.resolved,
            _ => true,
          },
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Report Triage'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: m.refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => _profile(context),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Kpi(title: 'Incoming', value: '${m.reports.length}'),
              _Kpi(
                title: 'Unverified',
                value:
                    '${m.reports.where((r) => r.status == ConflictReportStatus.unverified || r.status == ConflictReportStatus.pendingSync).length}',
              ),
              _Kpi(
                title: 'Critical',
                value:
                    '${m.reports.where((r) => r.severity == ThreatSeverity.critical).length}',
              ),
              _Kpi(
                title: 'Dispatched',
                value:
                    '${m.reports.where((r) => r.status == ConflictReportStatus.inProgress).length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: filter == f,
                        onSelected: (_) => setState(() => filter = f),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            _card(child: const Text('No reports in this queue yet.')),
          ...rows.map(
            (r) => _ReportCard(
              report: r,
              villager: false,
              onTap: () => _review(context, r),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newBroadcast(context),
        icon: const Icon(Icons.campaign),
        label: const Text('Broadcast alert'),
      ),
    );
  }

  Future<void> _review(BuildContext context, CommunityConflictReport r) async {
    final manager = context.read<CommunityConflictManager>();
    final messenger = ScaffoldMessenger.of(context);
    final notes = TextEditingController(text: r.cloNotes ?? '');
    final instructions = TextEditingController(
      text: r.dispatchInstructions ?? '',
    );
    String? unit = r.rangerUnit;
    String? priority = r.dispatchPriority;
    ConflictReportStatus status = r.status;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Review ${r.id}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Report status'),
                  items: ConflictReportStatus.values
                      .where((s) => s != ConflictReportStatus.pendingSync)
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                      )
                      .toList(),
                  onChanged: (v) => set(() => status = v ?? status),
                ),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(
                    labelText: 'Ranger unit (for dispatch)',
                  ),
                  items:
                      const [
                            'Alpha Unit - Rapid Response',
                            'Bravo Unit - Corridor Patrol',
                            'Charlie Unit - Veterinary & Dart',
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => set(() => unit = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Dispatch priority',
                  ),
                  items: const ['P1 - Immediate', 'P2 - Urgent', 'P3 - Routine']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => set(() => priority = v),
                ),
                TextField(
                  controller: instructions,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Tactical field instructions',
                  ),
                ),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'CLO notes / safety advisory',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await manager.updateStatus(
                        r,
                        status,
                        notes: notes.text,
                        unit: unit,
                        priority: priority,
                        instructions: instructions.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snackFrom(
                        messenger,
                        'Report updated. Published alert is visible to villagers.',
                      );
                    } catch (e) {
                      _snackFrom(messenger, e.toString());
                    }
                  },
                  child: const Text('SAVE REVIEW / DISPATCH'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    notes.dispose();
    instructions.dispose();
  }

  Future<void> _newBroadcast(BuildContext context) async {
    final manager = context.read<CommunityConflictManager>();
    final messenger = ScaffoldMessenger.of(context);
    final title = TextEditingController(),
        zone = TextEditingController(),
        advice = TextEditingController();
    ThreatSeverity severity = ThreatSeverity.high;
    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Emergency community broadcast'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Alert title / conflict type',
                  ),
                ),
                TextField(
                  controller: zone,
                  decoration: const InputDecoration(
                    labelText: 'Village zone / sector',
                  ),
                ),
                TextField(
                  controller: advice,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Safety advisory',
                  ),
                ),
                DropdownButton<ThreatSeverity>(
                  value: severity,
                  items: ThreatSeverity.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.code)),
                      )
                      .toList(),
                  onChanged: (v) => set(() => severity = v ?? severity),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await manager.createBroadcast(
                    title: title.text,
                    zone: zone.text,
                    advisory: advice.text,
                    severity: severity,
                  );
                  if (d.mounted) Navigator.pop(d);
                  _snackFrom(messenger, 'Community alert published.');
                } catch (e) {
                  _snackFrom(messenger, e.toString());
                }
              },
              child: const Text('PUBLISH'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    zone.dispose();
    advice.dispose();
  }
}

class LiaisonAlertsManagementScreen extends StatelessWidget {
  const LiaisonAlertsManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<CommunityConflictManager>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Published Alerts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: m.refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => _profile(context),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: m.alerts.isEmpty
          ? const Center(child: Text('No active broadcasts'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: m.alerts
                  .map(
                    (a) => _AlertCard(
                      alert: a,
                      canResolve: true,
                      onResolve: () => m.resolveAlert(a),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title, value;
  const _Kpi({required this.title, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width / 2 - 24,
    child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(title),
        ],
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  final CommunityConflictReport report;
  final bool villager;
  final VoidCallback? onTap;
  const _ReportCard({required this.report, required this.villager, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: ListTile(
      onTap: onTap,
      leading: Icon(
        Icons.pets,
        color: report.severity == ThreatSeverity.critical
            ? AppColors.failedRed
            : AppColors.primary,
      ),
      title: Text(
        '${report.type} • ${report.id}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${report.channel}  ·  ${report.zone}\n${report.reporterName}${report.reporterPhone == null ? '' : ' · ${report.reporterPhone}'}\n${report.description}\n${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}${report.rangerUnit == null ? '' : '\n${report.rangerUnit} dispatched'}${report.cloNotes == null ? '' : '\nCLO: ${report.cloNotes}'}',
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            report.severity.code,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: report.severity == ThreatSeverity.critical
                  ? AppColors.failedRed
                  : AppColors.pendingAmber,
            ),
          ),
          Text(report.status.label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );
}

class _AlertCard extends StatelessWidget {
  final CommunityAlertPost alert;
  final bool canResolve;
  final VoidCallback? onResolve;
  const _AlertCard({
    required this.alert,
    this.canResolve = false,
    this.onResolve,
  });
  @override
  Widget build(BuildContext context) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              alert.resolved ? 'ALL CLEAR' : alert.severity,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: alert.resolved
                    ? AppColors.syncedGreen
                    : AppColors.failedRed,
              ),
            ),
          ],
        ),
        Text('Zone: ${alert.zone}'),
        const SizedBox(height: 8),
        Text(alert.advisory),
        const SizedBox(height: 8),
        Text(
          '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}  ·  ${alert.publishedAt.toLocal()}',
        ),
        if (alert.rangerEnRoute)
          const Text(
            'Ranger unit en route',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (canResolve && !alert.resolved)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onResolve,
              child: const Text('MARK ALL CLEAR'),
            ),
          ),
      ],
    ),
  );
}
