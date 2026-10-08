import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/auth_manager.dart';
import '../../viewmodels/offline_sync_manager.dart';
import '../../models/incident_model.dart';
import '../login_screen.dart';

/// Team Boundary - Placeholder for UC03: Early Warning & Villager Alerts.
/// Assigned to Team Member 3.
class CommunityAlertsPlaceholderScreen extends StatelessWidget {
  const CommunityAlertsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authManager = context.watch<AuthManager>();
    final incidents = context.watch<OfflineSyncManager>().incidents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UC03: Villager Alerts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
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
      body: incidents.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.campaign_outlined, size: 56, color: Colors.blueGrey),
              const SizedBox(height: 12),
              const Text('No community alerts right now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Urgent wildlife and safety reports will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Chip(label: Text('Welcome, ${authManager.rangerDisplayName}'), backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
            ])))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: incidents.length,
              itemBuilder: (context, index) => _AlertCard(incident: incidents[incidents.length - 1 - index]),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IncidentModel incident;
  const _AlertCard({required this.incident});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.warning_amber_rounded)),
      title: Text(incident.type.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${incident.description}\n${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}'),
      isThreeLine: true,
      trailing: Text(incident.severity.displayName),
    ),
  );
}
