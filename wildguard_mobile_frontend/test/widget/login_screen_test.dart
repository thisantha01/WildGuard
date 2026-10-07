import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/screens/login_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/services/location_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';
import 'package:wildguard_mobile_frontend/viewmodels/offline_sync_manager.dart';

class MockTestIncidentRepo implements IncidentRepository {
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
  @override
  Future<List<IncidentModel>> fetchRemoteIncidentHistory() async => [];
}

class FakeLoginLocationService extends LocationService {
  @override
  Future<Map<String, double>?> getCurrentCoordinates() async {
    return {'latitude': 6.3721, 'longitude': 81.4012};
  }
}

void main() {
  Widget createLoginTestWidget({AuthManager? authManager}) {
    final auth = authManager ?? AuthManager(apiService: ApiService());
    final syncManager = OfflineSyncManager(
      repository: MockTestIncidentRepo(),
      locationService: FakeLoginLocationService(),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthManager>.value(value: auth),
        ChangeNotifierProvider<OfflineSyncManager>.value(value: syncManager),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders WildGuard branding and input fields', (WidgetTester tester) async {
      await tester.pumpWidget(createLoginTestWidget());

      // Branding
      expect(find.text('WildGuard'), findsOneWidget);
      expect(find.text('WildGuard Conservation Portal'), findsOneWidget);

      // Form Elements & Buttons
      expect(find.byKey(const Key('login_username_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.text('LOG IN'), findsOneWidget);
      expect(find.text('REGISTER'), findsOneWidget);
      expect(find.byKey(const Key('login_offline_bypass_button')), findsOneWidget);
    });

    testWidgets('Tapping Continue in Offline Field Mode navigates without error', (WidgetTester tester) async {
      final authManager = AuthManager(apiService: ApiService());
      await tester.pumpWidget(createLoginTestWidget(authManager: authManager));

      final bypassFinder = find.byKey(const Key('login_offline_bypass_button'));
      expect(bypassFinder, findsOneWidget);

      await tester.ensureVisible(bypassFinder);
      await tester.tap(bypassFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authManager.isOfflineGuestMode, isTrue);
    });
  });
}
