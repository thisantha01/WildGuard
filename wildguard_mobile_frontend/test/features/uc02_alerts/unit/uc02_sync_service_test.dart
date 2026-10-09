import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/data/datasources/uc02_remote_datasource.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/data/services/uc02_sync_service.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/entities/alert_action.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/action_queue_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/action_type.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/repositories/alert_action_repository.dart';

class FakeAlertActionRepository implements AlertActionRepository {
  List<AlertAction> pendingList = [];
  final List<String> markedSynced = [];
  final List<String> markedFailed = [];

  @override
  Future<int> getPendingCount() async => pendingList.length;

  @override
  Future<List<AlertAction>> getPendingActions() async => List.from(pendingList);

  @override
  Future<void> markSynced(String clientActionId) async {
    markedSynced.add(clientActionId);
  }

  @override
  Future<void> markFailed(String clientActionId, String reason) async {
    markedFailed.add(clientActionId);
  }

  @override
  Future<void> incrementRetry(String clientActionId) async {}

  @override
  Future<AlertStatus> performAction({
    required String alertId,
    required AlertStatus currentStatus,
    required ActionType type,
    required Map<String, dynamic> payload,
  }) async => AlertStatus.acknowledged;
}

class FakeRemoteDataSource extends Uc02RemoteDataSource {
  Map<String, dynamic>? batchResponse;

  @override
  Future<Map<String, dynamic>> syncBatch(
    List<AlertAction> actions,
    String token,
  ) async {
    return batchResponse ??
        {
          'results': actions.map((a) => {
                'clientActionId': a.clientActionId,
                'status': 'APPLIED',
              }).toList(),
          'applied': actions.length,
          'duplicates': 0,
          'rejected': 0,
        };
  }
}

void main() {
  group('Uc02SyncService Tests', () {
    late FakeAlertActionRepository actionRepo;
    late FakeRemoteDataSource remote;
    late Uc02SyncService syncService;

    setUp(() {
      actionRepo = FakeAlertActionRepository();
      remote = FakeRemoteDataSource();
      syncService = Uc02SyncService(
        actionRepo: actionRepo,
        remote: remote,
        tokenGetter: () => 'valid-jwt-token',
      );
    });

    test('syncNow returns 0 when queue is empty', () async {
      actionRepo.pendingList = [];

      final processed = await syncService.syncNow();
      expect(processed, 0);
      expect(actionRepo.markedSynced, isEmpty);
    });

    test('syncNow processes APPLIED, DUPLICATE, and REJECTED batch results', () async {
      final action1 = AlertAction(
        clientActionId: 'act-001',
        alertId: 'alt-1',
        type: ActionType.acknowledge,
        queueStatus: ActionQueueStatus.pending,
        occurredAt: DateTime.now(),
        payload: {},
      );
      final action2 = AlertAction(
        clientActionId: 'act-002',
        alertId: 'alt-2',
        type: ActionType.confirmDispatch,
        queueStatus: ActionQueueStatus.pending,
        occurredAt: DateTime.now(),
        payload: {},
      );
      final action3 = AlertAction(
        clientActionId: 'act-003',
        alertId: 'alt-3',
        type: ActionType.arrived,
        queueStatus: ActionQueueStatus.pending,
        occurredAt: DateTime.now(),
        payload: {},
      );

      actionRepo.pendingList = [action1, action2, action3];
      remote.batchResponse = {
        'results': [
          {'clientActionId': 'act-001', 'status': 'APPLIED'},
          {'clientActionId': 'act-002', 'status': 'DUPLICATE'},
          {'clientActionId': 'act-003', 'status': 'REJECTED', 'reason': 'Alert already resolved'},
        ],
        'applied': 1,
        'duplicates': 1,
        'rejected': 1,
      };

      final processed = await syncService.syncNow();

      expect(processed, 2); // 1 APPLIED + 1 DUPLICATE synced
      expect(actionRepo.markedSynced, contains('act-001'));
      expect(actionRepo.markedSynced, contains('act-002')); // DUPLICATE also marked synced
      expect(actionRepo.markedFailed, contains('act-003')); // REJECTED marked failed
    });
  });
}
