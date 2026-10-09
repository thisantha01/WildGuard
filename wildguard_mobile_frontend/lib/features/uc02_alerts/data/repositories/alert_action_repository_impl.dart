import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/alert_action.dart';
import '../../domain/enums/action_queue_status.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../../domain/repositories/alert_action_repository.dart';
import '../datasources/uc02_local_datasource.dart';
import '../datasources/uc02_remote_datasource.dart';

/// Provides the action-to-next-status mapping — the single source of truth
/// for what status an alert transitions to after each action.
AlertStatus _nextStatus(ActionType type) {
  switch (type) {
    case ActionType.acknowledge:
      return AlertStatus.acknowledged;
    case ActionType.decline:
      return AlertStatus.notified; // stays notified, will be reassigned
    case ActionType.confirmDispatch:
      return AlertStatus.inProgress;
    case ActionType.arrived:
      return AlertStatus.pendingResolution;
    case ActionType.fieldReport:
      return AlertStatus.resolved;
  }
}

/// Validates that an action is permitted given the current alert status.
/// Mirrors the backend `switch` in [RangerAlertController.getAlertDetail].
void _assertActionAllowed(ActionType type, AlertStatus currentStatus) {
  switch (type) {
    case ActionType.acknowledge:
    case ActionType.decline:
      if (currentStatus != AlertStatus.notified) {
        throw ValidationException(
          'Action ${type.toJson()} is only allowed in NOTIFIED status.',
        );
      }
      break;
    case ActionType.confirmDispatch:
      if (currentStatus != AlertStatus.acknowledged) {
        throw ValidationException(
          'CONFIRM_DISPATCH is only allowed in ACKNOWLEDGED status.',
        );
      }
      break;
    case ActionType.arrived:
      if (currentStatus != AlertStatus.inProgress &&
          currentStatus != AlertStatus.pendingResolution) {
        throw ValidationException(
          'ARRIVED is only allowed in IN_PROGRESS or PENDING_RESOLUTION status.',
        );
      }
      break;
    case ActionType.fieldReport:
      if (currentStatus != AlertStatus.pendingResolution &&
          currentStatus != AlertStatus.inProgress) {
        throw ValidationException(
          'SUBMIT_FIELD_REPORT is only allowed in PENDING_RESOLUTION or IN_PROGRESS status.',
        );
      }
      break;
  }
}

/// Concrete implementation of [AlertActionRepository].
///
/// Execution model (online-first, never blocks the UI):
/// 1. Validate action is allowed for current status.
/// 2. If online → attempt direct API call.
///    - Success: update local cache status, return new status.
///    - Network error: fall through to step 3.
/// 3. If offline or API network-failed → enqueue action in SQLite,
///    apply optimistic status update to cache, return optimistic status.
/// 4. Non-network errors (400/403/409) are NOT queued; surface to UI.
class AlertActionRepositoryImpl implements AlertActionRepository {
  final Uc02RemoteDataSource _remote;
  final Uc02DatabaseHelper _local;
  final bool Function() _isOnline;
  final String? Function() _tokenGetter;

  static const int _maxRetries = 5;

  AlertActionRepositoryImpl({
    required Uc02RemoteDataSource remote,
    required Uc02DatabaseHelper local,
    required bool Function() isOnline,
    required String? Function() tokenGetter,
  })  : _remote = remote,
        _local = local,
        _isOnline = isOnline,
        _tokenGetter = tokenGetter;

  @override
  Future<AlertStatus> performAction({
    required String alertId,
    required AlertStatus currentStatus,
    required ActionType type,
    required Map<String, dynamic> payload,
  }) async {
    _assertActionAllowed(type, currentStatus);

    final token = _tokenGetter();
    final online = _isOnline() && token != null && token.isNotEmpty;

    if (online) {
      try {
        await _callApi(alertId, type, payload, token);
        final next = (currentStatus == AlertStatus.pendingResolution && type == ActionType.arrived)
            ? AlertStatus.pendingResolution
            : _nextStatus(type);
        await _local.updateAlertStatus(alertId, next.toJson());
        debugPrint('[UC02] Action ${type.toJson()} on $alertId → $next (online)');
        return next;
      } on NetworkSyncException {
        return _enqueueAndOptimistic(alertId, type, payload, currentStatus);
      } on SocketException {
        return _enqueueAndOptimistic(alertId, type, payload, currentStatus);
      }
    }

    return _enqueueAndOptimistic(alertId, type, payload, currentStatus);
  }

  Future<AlertStatus> _enqueueAndOptimistic(
    String alertId,
    ActionType type,
    Map<String, dynamic> payload,
    AlertStatus currentStatus,
  ) async {
    final action = AlertAction(
      clientActionId:
          '${type.toJson()}_${alertId}_${DateTime.now().millisecondsSinceEpoch}',
      alertId: alertId,
      type: type,
      occurredAt: DateTime.now().toUtc(),
      payload: payload,
      queueStatus: ActionQueueStatus.pending,
    );
    await _local.enqueueAction(action);

    final optimistic = _nextStatus(type);
    await _local.updateAlertStatus(alertId, optimistic.toJson());
    debugPrint(
      '[UC02] Action ${type.toJson()} on $alertId QUEUED offline. Optimistic → $optimistic',
    );
    return optimistic;
  }

  Future<void> _callApi(
    String alertId,
    ActionType type,
    Map<String, dynamic> payload,
    String token,
  ) async {
    switch (type) {
      case ActionType.acknowledge:
        await _remote.acknowledge(alertId, token);
        break;
      case ActionType.decline:
        await _remote.decline(alertId, payload['reason'] as String, token);
        break;
      case ActionType.confirmDispatch:
        await _remote.confirmDispatch(alertId, token);
        break;
      case ActionType.arrived:
        await _remote.arrived(alertId, token);
        break;
      case ActionType.fieldReport:
        await _remote.submitFieldReport(alertId, payload, token);
        break;
    }
  }

  @override
  Future<List<AlertAction>> getPendingActions() =>
      _local.getPendingActions();

  @override
  Future<int> getPendingCount() => _local.getPendingCount();

  @override
  Future<void> markSynced(String clientActionId) =>
      _local.updateActionStatus(clientActionId, ActionQueueStatus.synced);

  @override
  Future<void> markFailed(String clientActionId, String reason) =>
      _local.updateActionStatus(
        clientActionId,
        ActionQueueStatus.failed,
        failureReason: reason,
      );

  @override
  Future<void> incrementRetry(String clientActionId) =>
      _local.incrementRetry(clientActionId);

  int get maxRetries => _maxRetries;
}
