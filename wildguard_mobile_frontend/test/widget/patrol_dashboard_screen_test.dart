import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/core/constants/app_strings.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/incident_type.dart';
import 'package:wildguard_mobile_frontend/models/sync_status.dart';
import 'package:wildguard_mobile_frontend/models/user_auth_model.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/screens/patrol_dashboard_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/services/connectivity_service.dart';
import 'package:wildguard_mobile_frontend/services/location_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';
import 'package:wildguard_mobile_frontend/viewmodels/offline_sync_manager.dart';

class MockDashboardIncidentRepo implements IncidentRepository {
  List<IncidentModel> mockIncidents = [];

  MockDashboardIncidentRepo([List<IncidentModel>? initial]) {
    if (initial != null) mockIncidents = initial;
  }

  @override
  Future<void> saveIncidentLocally(IncidentModel incident) async {
    mockIncidents.add(incident);
  }

  @override
  Future<List<IncidentModel>> getAllIncidents() async => List.from(mockIncidents);

  @override
  Future<List<IncidentModel>> getPendingIncidents() async =>
      mockIncidents.where((i) => i.syncStatus == SyncStatus.pending).toList();

  @override
  Future<Map<String, dynamic>> syncSingleIncident(IncidentModel incident) async => {
        'serverIncidentId': 'srv-123',
        'status': 'SYNCED',
        'duplicateFlag': false,
      };

  @override
  Future<void> markIncidentAsSynced(String localId, String serverId, {bool? duplicateFlag}) async {}

  @override
  Future<void> markIncidentAsFailed(String localId) async {}

  @override
  Future<List<IncidentModel>> fetchRemoteIncidentHistory() async => [];
}

class FakeDashboardLocationService extends LocationService {
  @override
  Future<Map<String, double>?> getCurrentCoordinates() async {
    return {'latitude': 6.3721, 'longitude': 81.4012};
  }

  @override
  Map<String, double> getFallbackReserveCoordinates() {
    return {'latitude': 6.3685, 'longitude': 81.5167};
  }
}

class FakeDashboardConnectivityService extends ConnectivityService {
  @override
  Future<bool> isOnline() async => true;
}

class FakeDashboardAuthManager extends AuthManager {
  final UserAuthModel? user;
  final bool guestMode;

  FakeDashboardAuthManager({this.user, this.guestMode = false}) : super(apiService: ApiService()) {
    if (guestMode) {
      continueOffline();
    }
  }

  @override
  UserAuthModel? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;

  @override
  bool get isOfflineGuestMode => guestMode;
}

void main() {
  Widget createDashboardWidget({
    UserAuthModel? user,
    bool isGuest = false,
    List<IncidentModel>? incidents,
    void Function(int)? onNavigateTab,
  }) {
    final fakeAuth = FakeDashboardAuthManager(user: user, guestMode: isGuest);
    final repo = MockDashboardIncidentRepo(incidents);
    final syncManager = OfflineSyncManager(
      repository: repo,
      locationService: FakeDashboardLocationService(),
      connectivityService: FakeDashboardConnectivityService(),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthManager>.value(value: fakeAuth),
        ChangeNotifierProvider<OfflineSyncManager>.value(value: syncManager),
      ],
      child: MaterialApp(
        home: PatrolDashboardScreen(onNavigateTab: onNavigateTab),
      ),
    );
  }

  group('PatrolDashboardScreen Widget Tests', () {
    testWidgets('Renders Ranger identity card with user name, badge ID, and online status', (WidgetTester tester) async {
      const rangerUser = UserAuthModel(
        userId: 'u1',
        username: 'ranger_test',
        email: 'ranger@wildguard.org',
        fullName: 'Kamal Perera',
        role: 'ROLE_RANGER',
        badgeNumber: 'WG-RNG-002',
        assignedPark: 'Yala National Park',
        token: 'jwt-token-123',
      );

      await tester.pumpWidget(createDashboardWidget(user: rangerUser));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.patrolDashboardTitle), findsOneWidget);
      expect(find.text('Kamal Perera'), findsOneWidget);
      expect(find.text('WG-RNG-002'), findsOneWidget);
      expect(find.text('ROLE_RANGER'), findsOneWidget);
      expect(find.text('Yala National Park'), findsOneWidget);
      expect(find.text('Online (Connected)'), findsOneWidget);
    });

    testWidgets('Renders offline guest unit badge when in guest jungle mode', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget(isGuest: true));
      await tester.pumpAndSettle();

      expect(find.text('Field Patrol Unit'), findsOneWidget);
      expect(find.text('WG-RNG-OFFLINE'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsOneWidget);
    });

    testWidgets('Renders KPI telemetry cards with pending, synced, and total counts', (WidgetTester tester) async {
      final mockList = [
        IncidentModel(
          localIncidentId: 'loc-1',
          type: IncidentType.snare,
          severity: IncidentSeverity.high,
          description: 'Wire snare near water hole',
          latitude: 6.3721,
          longitude: 81.4012,
          timestamp: DateTime.now(),
          syncStatus: SyncStatus.pending,
        ),
        IncidentModel(
          localIncidentId: 'loc-2',
          type: IncidentType.carcass,
          severity: IncidentSeverity.critical,
          description: 'Deer carcass found',
          latitude: 6.3725,
          longitude: 81.4015,
          timestamp: DateTime.now(),
          syncStatus: SyncStatus.synced,
        ),
      ];

      await tester.pumpWidget(createDashboardWidget(incidents: mockList));
      await tester.pumpAndSettle();

      expect(find.text('Pending Sync'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // 1 pending
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('Synced to Base'), findsOneWidget);
      expect(find.text('Total Logged'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // 2 total logged
    });

    testWidgets('Rapping Primary Log Incident button triggers onNavigateTab(1)', (WidgetTester tester) async {
      int? navigatedTab;

      await tester.pumpWidget(createDashboardWidget(
        onNavigateTab: (index) => navigatedTab = index,
      ));
      await tester.pumpAndSettle();

      final logBtn = find.byKey(const Key('patrol_log_incident_button'));
      expect(logBtn, findsOneWidget);

      await tester.tap(logBtn);
      await tester.pump();

      expect(navigatedTab, equals(1));
    });

    testWidgets('Tapping Secondary View Sync Queue button triggers onNavigateTab(2)', (WidgetTester tester) async {
      int? navigatedTab;

      await tester.pumpWidget(createDashboardWidget(
        onNavigateTab: (index) => navigatedTab = index,
      ));
      await tester.pumpAndSettle();

      final syncBtn = find.byKey(const Key('patrol_view_sync_button'));
      expect(syncBtn, findsOneWidget);

      await tester.tap(syncBtn);
      await tester.pump();

      expect(navigatedTab, equals(2));
    });

    testWidgets('Renders Patrol Sector All-Clear when incident list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget(incidents: []));
      await tester.pumpAndSettle();

      expect(find.text('Patrol Sector All-Clear'), findsOneWidget);
      expect(find.text('No field incidents recorded today on this patrol shift.'), findsOneWidget);
    });

    testWidgets('Tapping Reserve Pin drops fallback reserve coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      final pinBtn = find.byKey(const Key('patrol_fallback_pin_button'));
      expect(pinBtn, findsOneWidget);
      await tester.ensureVisible(pinBtn);
      await tester.pumpAndSettle();

      await tester.tap(pinBtn);
      await tester.pumpAndSettle();

      expect(find.text('Yala National Park fallback pin pinned successfully.'), findsOneWidget);
    });

    testWidgets('Renders emergency dispatch protocol strip at the bottom', (WidgetTester tester) async {
      await tester.pumpWidget(createDashboardWidget());
      await tester.pumpAndSettle();

      final emergencyStrip = find.textContaining('EMERGENCY PROTOCOL: If armed poachers');
      await tester.ensureVisible(emergencyStrip);
      expect(emergencyStrip, findsOneWidget);
    });
  });
}
