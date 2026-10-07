import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/incident_type.dart';
import 'package:wildguard_mobile_frontend/models/sync_status.dart';
import 'package:wildguard_mobile_frontend/repositories/incident_repository_impl.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/services/database_service.dart';

class MockDatabaseService extends DatabaseService {
  final List<IncidentModel> list = [];

  @override
  Future<void> insertIncident(IncidentModel incident) async {
    list.add(incident);
  }

  @override
  Future<List<IncidentModel>> getAllIncidents() async => list;

  @override
  Future<List<IncidentModel>> getPendingIncidents() async =>
      list.where((i) => i.syncStatus == SyncStatus.pending).toList();

  @override
  Future<void> updateIncidentStatus(
    String localId,
    SyncStatus status, {
    String? serverId,
    bool? duplicateFlag,
    DateTime? syncedAt,
  }) async {
    final idx = list.indexWhere((i) => i.localIncidentId == localId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(
        syncStatus: status,
        serverIncidentId: serverId,
        duplicateFlag: duplicateFlag ?? false,
        syncedAt: syncedAt,
      );
    }
  }
}

class MockApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> syncIncident(IncidentModel incident) async {
    return {
      'localIncidentId': incident.localIncidentId,
      'serverIncidentId': 'server-101',
      'duplicateFlag': false,
    };
  }
}

void main() {
  late MockDatabaseService mockDb;
  late MockApiService mockApi;
  late IncidentRepositoryImpl repository;

  setUp(() {
    mockDb = MockDatabaseService();
    mockApi = MockApiService();
    repository = IncidentRepositoryImpl(
      databaseService: mockDb,
      apiService: mockApi,
    );
  });

  group('IncidentRepositoryImpl Tests', () {
    final testIncident = IncidentModel(
      localIncidentId: 'test-loc-1',
      type: IncidentType.trap,
      severity: IncidentSeverity.medium,
      description: 'Poacher trap',
      latitude: 6.36,
      longitude: 81.52,
      timestamp: DateTime.now(),
    );

    test('saveIncidentLocally inserts incident in database', () async {
      await repository.saveIncidentLocally(testIncident);
      final all = await repository.getAllIncidents();
      expect(all.length, 1);
      expect(all.first.localIncidentId, 'test-loc-1');
    });

    test('getPendingIncidents returns only pending items', () async {
      await repository.saveIncidentLocally(testIncident);
      final pending = await repository.getPendingIncidents();
      expect(pending.length, 1);
    });

    test('syncSingleIncident delegates to ApiService', () async {
      final res = await repository.syncSingleIncident(testIncident);
      expect(res['serverIncidentId'], 'server-101');
    });

    test('markIncidentAsSynced updates status and server ID', () async {
      await repository.saveIncidentLocally(testIncident);
      await repository.markIncidentAsSynced('test-loc-1', 'server-101');
      final all = await repository.getAllIncidents();
      expect(all.first.syncStatus, SyncStatus.synced);
      expect(all.first.serverIncidentId, 'server-101');
    });

    test('markIncidentAsFailed updates status to failed', () async {
      await repository.saveIncidentLocally(testIncident);
      await repository.markIncidentAsFailed('test-loc-1');
      final all = await repository.getAllIncidents();
      expect(all.first.syncStatus, SyncStatus.failed);
    });
  });
}
