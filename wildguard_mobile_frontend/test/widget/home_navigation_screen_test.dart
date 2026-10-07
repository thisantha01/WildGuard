import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/core/constants/app_strings.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/user_auth_model.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/screens/home_navigation_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';
import 'package:wildguard_mobile_frontend/viewmodels/offline_sync_manager.dart';

class MockIncidentRepo implements IncidentRepository {
  @override
  Future<void> saveIncidentLocally(IncidentModel incident) async {}
  @override
  Future<List<IncidentModel>> getAllIncidents() async => [];
  @override
  Future<List<IncidentModel>> getPendingIncidents() async => [];
  @override
  Future<Map<String, dynamic>> syncSingleIncident(IncidentModel incident) async => {};
  @override
  Future<void> markIncidentAsSynced(String localId, String serverId, {bool? duplicateFlag}) async {}
  @override
  Future<void> markIncidentAsFailed(String localId) async {}
}

class FakeRoleAuthManager extends AuthManager {
  final UserAuthModel? user;

  FakeRoleAuthManager(this.user) : super(apiService: ApiService());

  @override
  UserAuthModel? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;
}

void main() {
  Widget createNavTestWidget(UserAuthModel user) {
    final fakeAuth = FakeRoleAuthManager(user);
    final syncManager = OfflineSyncManager(repository: MockIncidentRepo());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthManager>.value(value: fakeAuth),
        ChangeNotifierProvider<OfflineSyncManager>.value(value: syncManager),
      ],
      child: const MaterialApp(
        home: HomeNavigationScreen(),
      ),
    );
  }

  group('Role-Based Access Control (RBAC) Navigation Tests', () {
    testWidgets('Ranger sees ONLY Ranger-specific pages (Log Incident & Sync Manager)', (WidgetTester tester) async {
      const rangerUser = UserAuthModel(
        userId: 'u1',
        username: 'ranger_test',
        email: 'ranger@wildguard.org',
        fullName: 'Kamal Perera',
        role: 'ROLE_RANGER',
        token: 'token-123',
      );

      await tester.pumpWidget(createNavTestWidget(rangerUser));
      await tester.pump();

      // Should display Ranger tabs
      expect(find.text(AppStrings.tabLogIncident), findsOneWidget);
      expect(find.text(AppStrings.tabSyncManager), findsOneWidget);

      // Should NOT display Manager or Liaison tabs
      expect(find.text('Analytics'), findsNothing);
      expect(find.text('Sensor Feeds'), findsNothing);
      expect(find.text('Community Reports'), findsNothing);
    });

    testWidgets('Manager sees ONLY Manager-specific pages (Analytics & Sensor Feeds)', (WidgetTester tester) async {
      const managerUser = UserAuthModel(
        userId: 'u2',
        username: 'manager_test',
        email: 'manager@wildguard.org',
        fullName: 'Sarath Silva',
        role: 'ROLE_MANAGER',
        token: 'token-456',
      );

      await tester.pumpWidget(createNavTestWidget(managerUser));
      await tester.pump();

      // Should display Manager tabs
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Sensor Feeds'), findsOneWidget);

      // Should NOT display Ranger or Liaison tabs
      expect(find.text(AppStrings.tabLogIncident), findsNothing);
      expect(find.text(AppStrings.tabSyncManager), findsNothing);
      expect(find.text('Community Reports'), findsNothing);
    });

    testWidgets('Liaison Officer sees ONLY Liaison-specific page (Community Reports)', (WidgetTester tester) async {
      const liaisonUser = UserAuthModel(
        userId: 'u3',
        username: 'liaison_test',
        email: 'liaison@wildguard.org',
        fullName: 'Anula Jayasinghe',
        role: 'ROLE_LIAISON',
        token: 'token-789',
      );

      await tester.pumpWidget(createNavTestWidget(liaisonUser));
      await tester.pump();

      // Should display Liaison tabs
      expect(find.text('Conflict Reports'), findsOneWidget);
      expect(find.text('Villager Alerts'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Should NOT render Ranger or Manager tabs
      expect(find.text(AppStrings.tabLogIncident), findsNothing);
      expect(find.text('Analytics'), findsNothing);
    });
  });
}
