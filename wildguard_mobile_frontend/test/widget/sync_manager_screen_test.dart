import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/core/constants/app_strings.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/incident_type.dart';
import 'package:wildguard_mobile_frontend/models/sync_status.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository.dart';
import 'package:wildguard_mobile_frontend/screens/sync_manager_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';
import 'package:wildguard_mobile_frontend/viewmodels/offline_sync_manager.dart';

class MockIncidentRepository implements IncidentRepository {
  final List<IncidentModel> items;
  MockIncidentRepository(this.items);

  @override
  Future<void> saveIncidentLocally(IncidentModel incident) async {}
  @override
  Future<List<IncidentModel>> getAllIncidents() async => items;
  @override
  Future<List<IncidentModel>> getPendingIncidents() async => items.where((i) => i.syncStatus == SyncStatus.pending).toList();
  @override
  Future<Map<String, dynamic>> syncSingleIncident(IncidentModel incident) async => {};
  @override
  Future<void> markIncidentAsSynced(String localId, String serverId, {bool? duplicateFlag}) async {}
  @override
  Future<void> markIncidentAsFailed(String localId) async {}
  @override
  Future<List<IncidentModel>> fetchRemoteIncidentHistory() async => [];
}

void main() {
  testWidgets('SyncManagerScreen renders [ SYNC ALL PENDING ] button and color psychology tags', (WidgetTester tester) async {
    final sampleIncident = IncidentModel(
      localIncidentId: 'loc-1',
      type: IncidentType.snare,
      severity: IncidentSeverity.high,
      description: 'Wire snare near water point',
      latitude: 6.3685,
      longitude: 81.5273,
      timestamp: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    final mockRepo = MockIncidentRepository([sampleIncident]);
    final manager = OfflineSyncManager(repository: mockRepo);
    await manager.loadIncidents();

    final authManager = AuthManager(apiService: ApiService());

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
            ChangeNotifierProvider<AuthManager>.value(value: authManager),
          ],
          child: const SyncManagerScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify Dashboard Title
    expect(find.text(AppStrings.syncDashboardTitle), findsOneWidget);

    // Verify Primary Action Button: [ 🔄 SYNC ALL PENDING ]
    expect(find.text(AppStrings.syncAllPendingButtonText), findsOneWidget);
    expect(find.byKey(const Key('sync_all_pending_button')), findsOneWidget);

    // Verify Status Tag: PENDING tag rendered
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets('SyncManagerScreen renders empty state and Fetch My Reports button when no incidents exist', (WidgetTester tester) async {
    final mockRepo = MockIncidentRepository([]);
    final manager = OfflineSyncManager(repository: mockRepo);
    await manager.loadIncidents(fetchRemote: false);

    final authManager = AuthManager(apiService: ApiService());

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
            ChangeNotifierProvider<AuthManager>.value(value: authManager),
          ],
          child: const SyncManagerScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.emptyIncidentListText), findsOneWidget);
    expect(find.text('Fetch My Reports from Base Station'), findsOneWidget);
  });

  testWidgets('SyncManagerScreen renders RETRY button and failure prompt for FAILED incident', (WidgetTester tester) async {
    final failedIncident = IncidentModel(
      localIncidentId: 'loc-failed-1',
      type: IncidentType.poacherTrack,
      severity: IncidentSeverity.critical,
      description: 'Poacher tracks spotted',
      latitude: 6.3685,
      longitude: 81.5273,
      timestamp: DateTime.now(),
      syncStatus: SyncStatus.failed,
    );

    final mockRepo = MockIncidentRepository([failedIncident]);
    final manager = OfflineSyncManager(repository: mockRepo);
    await manager.loadIncidents();

    final authManager = AuthManager(apiService: ApiService());

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<OfflineSyncManager>.value(value: manager),
            ChangeNotifierProvider<AuthManager>.value(value: authManager),
          ],
          child: const SyncManagerScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify FAILED tag rendered
    expect(find.text('FAILED'), findsOneWidget);
    // Verify RETRY button rendered
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.byKey(const Key('retry_button_loc-failed-1')), findsOneWidget);
  });
}
