import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../viewmodels/auth_manager.dart';
import 'log_incident_screen.dart';
import 'patrol_dashboard_screen.dart';
import 'placeholders/analytics_placeholder_screen.dart';
import 'placeholders/community_alerts_placeholder_screen.dart';
import 'placeholders/community_placeholder_screen.dart';
import 'placeholders/geofence_placeholder_screen.dart';
import 'sync_manager_screen.dart';
import 'log_incident_screen.dart';

/// Navigation destination model bound to specific roles.
class _RoleNavDestination {
  final Widget screen;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _RoleNavDestination({
    required this.screen,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// Dynamic navigation shell displaying strictly the screens permitted for the logged-in role.
class HomeNavigationScreen extends StatefulWidget {
  const HomeNavigationScreen({super.key});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;

  /// Returns only the destinations authorized for the specified role.
  List<_RoleNavDestination> _getDestinationsForRole(String role) {
    if (role.contains('VILLAGER')) {
      return [
        const _RoleNavDestination(
          screen: CommunityAlertsPlaceholderScreen(),
          label: 'Community Alerts',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
        ),
        _RoleNavDestination(
          screen: LogIncidentScreen(villagerMode: true),
          label: 'Report Incident',
          icon: Icons.add_location_alt_outlined,
          activeIcon: Icons.add_location_alt_rounded,
        ),
      ];
    } else if (role.contains('MANAGER')) {
      // Park Manager: Supervisory view for Analytics & Sensor Geofences
      return const [
        _RoleNavDestination(
          screen: AnalyticsPlaceholderScreen(),
          label: 'Analytics',
          icon: Icons.insights_outlined,
          activeIcon: Icons.insights_rounded,
        ),
        _RoleNavDestination(
          screen: GeofencePlaceholderScreen(),
          label: 'Sensor Feeds',
          icon: Icons.radar_outlined,
          activeIcon: Icons.radar_rounded,
        ),
      ];
    } else if (role.contains('LIAISON')) {
      // Community Liaison Officer: Community human-wildlife conflict reports (UC03)
      return const [
        _RoleNavDestination(
          screen: CommunityPlaceholderScreen(),
          label: 'Conflict Reports',
          icon: Icons.report_problem_outlined,
          activeIcon: Icons.report_problem_rounded,
        ),
        _RoleNavDestination(
          screen: CommunityAlertsPlaceholderScreen(),
          label: 'Villager Alerts',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
        ),
      ];
    } else {
      // Field Ranger (ROLE_RANGER or Offline Field Mode): Patrol Hub, Incident Logging, and Sync Manager (UC01)
      return [
        _RoleNavDestination(
          screen: PatrolDashboardScreen(
            onNavigateTab: (index) => setState(() => _currentIndex = index),
          ),
          label: AppStrings.tabPatrolDashboard,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
        ),
        _RoleNavDestination(
          screen: LogIncidentScreen(
            onReturnToDashboard: () => setState(() => _currentIndex = 0),
          ),
          label: AppStrings.tabLogIncident,
          icon: Icons.add_location_alt_outlined,
          activeIcon: Icons.add_location_alt_rounded,
        ),
        const _RoleNavDestination(
          screen: SyncManagerScreen(),
          label: AppStrings.tabSyncManager,
          icon: Icons.sync_outlined,
          activeIcon: Icons.sync_rounded,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authManager = context.watch<AuthManager>();
    final role = authManager.currentUser?.role ?? 'ROLE_RANGER';
    final destinations = _getDestinationsForRole(role);

    // Keep currentIndex within range if role changes
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: destinations.map((d) {
          return BottomNavigationBarItem(
            icon: Icon(d.icon),
            activeIcon: Icon(d.activeIcon),
            label: d.label,
          );
        }).toList(),
      ),
    );
  }
}
