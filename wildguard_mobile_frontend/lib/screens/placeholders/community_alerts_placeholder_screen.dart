import 'package:flutter/material.dart';

import '../community_workspaces.dart';

/// Retains the historic import path; role-specific home navigation chooses the view.
class CommunityAlertsPlaceholderScreen extends StatelessWidget {
  const CommunityAlertsPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const VillagerCommunityDashboard();
}
