import 'dart:convert';
import '../enums/action_queue_status.dart';
import '../enums/action_type.dart';

/// Immutable domain entity representing a queued ranger action.
/// Stored in `uc02_action_queue` SQLite table when offline or when the
/// direct API call fails with a network error.
class AlertAction {
  final String clientActionId;
  final String alertId;
  final ActionType type;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;
  final ActionQueueStatus queueStatus;
  final int retryCount;
  final String? failureReason;

  const AlertAction({
    required this.clientActionId,
    required this.alertId,
    required this.type,
    required this.occurredAt,
    required this.payload,
    required this.queueStatus,
    this.retryCount = 0,
    this.failureReason,
  });

  /// Serialises to the `uc02_action_queue` SQLite row format.
  Map<String, dynamic> toMap() {
    return {
      'client_action_id': clientActionId,
      'alert_id': alertId,
      'type': type.toJson(),
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'payload_json': jsonEncode(payload),
      'queue_status': queueStatus.toJson(),
      'retry_count': retryCount,
      'failure_reason': failureReason,
    };
  }

  /// Deserialises from a SQLite row.
  factory AlertAction.fromMap(Map<String, dynamic> map) {
    final rawPayload = map['payload_json'] as String?;
    final payload = rawPayload != null
        ? jsonDecode(rawPayload) as Map<String, dynamic>
        : <String, dynamic>{};

    return AlertAction(
      clientActionId: map['client_action_id'] as String,
      alertId: map['alert_id'] as String,
      type: ActionType.fromJson(map['type'] as String),
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      payload: payload,
      queueStatus: ActionQueueStatus.fromJson(map['queue_status'] as String?),
      retryCount: map['retry_count'] as int? ?? 0,
      failureReason: map['failure_reason'] as String?,
    );
  }

  AlertAction copyWith({
    ActionQueueStatus? queueStatus,
    int? retryCount,
    String? failureReason,
  }) {
    return AlertAction(
      clientActionId: clientActionId,
      alertId: alertId,
      type: type,
      occurredAt: occurredAt,
      payload: payload,
      queueStatus: queueStatus ?? this.queueStatus,
      retryCount: retryCount ?? this.retryCount,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
