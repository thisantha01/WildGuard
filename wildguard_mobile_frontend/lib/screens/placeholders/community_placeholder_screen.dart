import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/auth_manager.dart';
import '../login_screen.dart';

/// Team Boundary - Placeholder for UC03: Process Community Conflict Reports.
/// Assigned to Team Member 3.
class CommunityPlaceholderScreen extends StatelessWidget {
  const CommunityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authManager = context.watch<AuthManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UC03: Community Conflict'),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline_rounded, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 16),
              const Text(
                'UC03: Community Conflict Reports',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reserved for Team Member 3\n(Villager reports & rapid response)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Chip(
                label: Text('Logged in: ${authManager.rangerDisplayName}'),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
