/// The type of action that a ranger performs on an alert.
/// Maps 1-to-1 with the `type` field in [SyncActionRequest].
enum ActionType {
  acknowledge,
  decline,
  confirmDispatch,
  arrived,
  fieldReport;

  /// Wire-format string sent to `POST /api/sync` and action endpoints.
  String toJson() {
    switch (this) {
      case ActionType.acknowledge:
        return 'ACKNOWLEDGE';
      case ActionType.decline:
        return 'DECLINE';
      case ActionType.confirmDispatch:
        return 'CONFIRM_DISPATCH';
      case ActionType.arrived:
        return 'ARRIVED';
      case ActionType.fieldReport:
        return 'FIELD_REPORT';
    }
  }

  static ActionType fromJson(String raw) {
    switch (raw) {
      case 'ACKNOWLEDGE':
        return ActionType.acknowledge;
      case 'DECLINE':
        return ActionType.decline;
      case 'CONFIRM_DISPATCH':
        return ActionType.confirmDispatch;
      case 'ARRIVED':
        return ActionType.arrived;
      case 'FIELD_REPORT':
        return ActionType.fieldReport;
      default:
        throw ArgumentError('Unknown ActionType: $raw');
    }
  }
}
