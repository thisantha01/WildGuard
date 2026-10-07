import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/core/constants/app_strings.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/user_auth_model.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/screens/log_incident_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/services/location_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';
import 'package:wildguard_mobile_frontend/viewmodels/offline_sync_manager.dart';

class MockIncidentRepository implements IncidentRepository {
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

class MockSuccessLocationService extends LocationService {
  @override
  Future<Map<String, double>?> getCurrentCoordinates() async {
    return {'latitude': 6.3721, 'longitude': 81.4012};
  }
}

class MockLostLocationService extends LocationService {
  @override
  Future<Map<String, double>?> getCurrentCoordinates() async {
    return null;
  }
}

class FakeAuthenticatedAuthManager extends AuthManager {
  final UserAuthModel? user;
  FakeAuthenticatedAuthManager(this.user) : super(apiService: ApiService());

  @override
  UserAuthModel? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;

  @override
  bool get isOfflineGuestMode => false;
}

void main() {
  Widget createTestWidget({
    LocationService? locationService,
    OfflineSyncManager? syncManager,
    AuthManager? authManager,
  }) {
    final mockRepo = MockIncidentRepository();
    final manager = syncManager ??
        OfflineSyncManager(
          repository: mockRepo,
          locationService: locationService ?? MockSuccessLocationService(),
        );
    final auth = authManager ?? AuthManager(apiService: ApiService());

    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
          ChangeNotifierProvider<AuthManager>.value(value: auth),
        ],
        child: const LogIncidentScreen(),
      ),
    );
  }

  group('LogIncidentScreen Widget Tests', () {
    testWidgets('Renders red OFFLINE MODE banner correctly when device cannot sync', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verify Top Banner: "⚠ OFFLINE MODE: Data will be saved to device."
      final bannerFinder = find.text(AppStrings.offlineBannerText);
      expect(bannerFinder, findsOneWidget);

      final warningIconFinder = find.byIcon(Icons.warning_amber_rounded);
      expect(warningIconFinder, findsWidgets);
    });

    testWidgets('Hides red OFFLINE MODE banner when device can sync with database', (WidgetTester tester) async {
      final mockRepo = MockIncidentRepository();
      final manager = OfflineSyncManager(
        repository: mockRepo,
        locationService: MockSuccessLocationService(),
      )..setOnlineStatus(true);

      const loggedInRanger = UserAuthModel(
        userId: 'usr-1',
        username: 'ranger_sarath',
        email: 'sarath@wildguard.org',
        fullName: 'Sarath Gunawardena',
        role: 'ROLE_RANGER',
        token: 'mock-valid-jwt-token',
      );
      final authManager = FakeAuthenticatedAuthManager(loggedInRanger);

      await tester.pumpWidget(
        createTestWidget(
          syncManager: manager,
          authManager: authManager,
        ),
      );
      await tester.pump();

      // The red alert banner should NOT appear when device can sync with database
      expect(find.text(AppStrings.offlineBannerText), findsNothing);
    });

    testWidgets('Renders prominent [ SAVE OFFLINE ] button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verify Context-Aware CTA Button: "[ SAVE OFFLINE ]"
      final saveButtonFinder = find.text(AppStrings.saveOfflineButtonText);
      expect(saveButtonFinder, findsOneWidget);

      // Verify key finder
      expect(find.byKey(const Key('save_offline_button')), findsOneWidget);
    });

    testWidgets('Renders Fitts\'s Law Photo touch targets and Offline Map Pin button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verify Photo Section Buttons
      expect(find.text(AppStrings.takePhotoButtonText), findsOneWidget);
      expect(find.text(AppStrings.selectGalleryButtonText), findsOneWidget);

      // Verify Location Drop Pin Button
      expect(find.text(AppStrings.dropPinButtonText), findsOneWidget);
    });

    testWidgets('Renders 2x2 large touch-target severity selector buttons and allows selection', (WidgetTester tester) async {
      final mockRepo = MockIncidentRepository();
      final manager = OfflineSyncManager(repository: mockRepo);
      final authManager = AuthManager(apiService: ApiService());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
              ChangeNotifierProvider<AuthManager>.value(value: authManager),
            ],
            child: const LogIncidentScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify all 4 severity buttons are visible
      expect(find.text('Incident Severity Level *'), findsOneWidget);
      expect(find.text('Low Severity'), findsOneWidget);
      expect(find.text('Medium Severity'), findsOneWidget);
      expect(find.text('High Severity'), findsOneWidget);
      expect(find.text('Critical Alert'), findsOneWidget);

      // Verify default is high
      expect(manager.selectedSeverity, IncidentSeverity.high);

      // Tap Critical Alert button
      final criticalFinder = find.byKey(const Key('severity_critical'));
      await tester.ensureVisible(criticalFinder);
      await tester.tap(criticalFinder);
      await tester.pump();

      // Verify severity changed
      expect(manager.selectedSeverity, IncidentSeverity.critical);
    });

    testWidgets('Automatically requests and populates GPS coordinates and OS timestamp upon opening', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(locationService: MockSuccessLocationService()));
      await tester.pumpAndSettle();

      // Verify exact coordinates are populated without asking user
      expect(find.textContaining('Lat: 6.3721, Lon: 81.4012'), findsOneWidget);
      expect(find.textContaining('OS Recorded Time:'), findsOneWidget);
    });

    testWidgets('Automatically warns ranger when exact GPS location cannot be located', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(locationService: MockLostLocationService()));
      await tester.pumpAndSettle();

      // Verify warning banner is displayed
      expect(find.byKey(const Key('gps_lost_warning_banner')), findsOneWidget);
      expect(find.textContaining('WARNING: Exact GPS coordinates could not be located'), findsWidgets);
    });

    testWidgets('Shows warning SnackBar when clicking Save Offline without description', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(locationService: MockSuccessLocationService()));
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_offline_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Please enter incident notes / description before saving.'), findsOneWidget);
    });

    testWidgets('Saves incident and shows success SnackBar when description and GPS are valid', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(locationService: MockSuccessLocationService()));
      await tester.pumpAndSettle();

      // Enter description
      final descField = find.byType(TextField);
      await tester.enterText(descField, 'Wire snare spotted near waterhole');
      await tester.pump();

      final saveButton = find.byKey(const Key('save_offline_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(AppStrings.savedOfflineSuccess), findsOneWidget);
    });

    testWidgets('Displays prominent visual success modal and returns Ranger to active patrol dashboard on dismiss', (WidgetTester tester) async {
      bool returnedToDashboard = false;
      final mockRepo = MockIncidentRepository();
      final manager = OfflineSyncManager(
        repository: mockRepo,
        locationService: MockSuccessLocationService(),
      );
      final authManager = AuthManager(apiService: ApiService());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
              ChangeNotifierProvider<AuthManager>.value(value: authManager),
            ],
            child: LogIncidentScreen(
              onReturnToDashboard: () => returnedToDashboard = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descField = find.byType(TextField);
      await tester.enterText(descField, 'Suspected wire snare found near tree');
      await tester.pump();

      final saveButton = find.byKey(const Key('save_offline_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify prominent visual success modal is rendered
      expect(find.text('Incident Saved to Device'), findsOneWidget);
      expect(find.text('Pending sync with base station'), findsOneWidget);

      // Tap Return to Patrol Dashboard button
      final returnButton = find.byKey(const Key('return_to_dashboard_button'));
      expect(returnButton, findsOneWidget);
      await tester.tap(returnButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify callback was invoked to unblock ranger workflow
      expect(returnedToDashboard, isTrue);
    });
  });
}
