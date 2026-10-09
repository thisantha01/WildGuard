import '../entities/alert_action.dart';
import '../enums/action_type.dart';
import '../enums/alert_status.dart';

/// Abstract contract for queueing and managing offline ranger actions.
/// Implemented by [AlertActionRepositoryImpl] in the data layer.
abstract class AlertActionRepository {
  /// Executes a ranger action:
  /// 1. If online, attempts the direct API call first.
  /// 2. If offline OR the call fails with a network error, saves the action
  ///    to the local queue and applies an optimistic status update.
  ///
  /// Returns the new [AlertStatus] after the action (optimistic if offline).
  Future<AlertStatus> performAction({
    required String alertId,
    required AlertStatus currentStatus,
    required ActionType type,
    required Map<String, dynamic> payload,
  });

  /// Returns all actions currently in PENDING status, ordered by [occurredAt].
  Future<List<AlertAction>> getPendingActions();

  /// Returns the total count of pending-sync actions (for the UI badge).
  Future<int> getPendingCount();

  /// Marks an action as successfully synced.
  Future<void> markSynced(String clientActionId);

  /// Marks an action as failed with a user-friendly [reason].
  Future<void> markFailed(String clientActionId, String reason);

  /// Increments the retry counter for an action.
  Future<void> incrementRetry(String clientActionId);
}
