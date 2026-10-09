/// Sync/queue status of a locally-queued ranger action.
enum ActionQueueStatus {
  pending,
  synced,
  failed;

  String toJson() => name.toUpperCase();

  static ActionQueueStatus fromJson(String? raw) {
    switch (raw) {
      case 'SYNCED':
        return ActionQueueStatus.synced;
      case 'FAILED':
        return ActionQueueStatus.failed;
      case 'PENDING':
      default:
        return ActionQueueStatus.pending;
    }
  }
}
