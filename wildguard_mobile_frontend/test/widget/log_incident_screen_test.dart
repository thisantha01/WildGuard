import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/core/constants/app_strings.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/screens/log_incident_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
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
}

void main() {
  Widget createTestWidget() {
    final mockRepo = MockIncidentRepository();
    final manager = OfflineSyncManager(repository: mockRepo);
    final authManager = AuthManager(apiService: ApiService());

    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
          ChangeNotifierProvider<AuthManager>.value(value: authManager),
        ],
        child: const LogIncidentScreen(),
      ),
    );
  }

  group('LogIncidentScreen Widget Tests', () {
    testWidgets('Renders red OFFLINE MODE banner correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verify Top Banner: "⚠ OFFLINE MODE: Data will be saved to device."
      final bannerFinder = find.text(AppStrings.offlineBannerText);
      expect(bannerFinder, findsOneWidget);

      final warningIconFinder = find.byIcon(Icons.warning_amber_rounded);
      expect(warningIconFinder, findsOneWidget);
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
  });
}
