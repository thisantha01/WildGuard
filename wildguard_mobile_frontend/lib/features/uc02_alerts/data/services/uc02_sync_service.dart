import 'package:flutter/foundation.dart';
import '../../domain/entities/alert_action.dart';
import '../../domain/repositories/alert_action_repository.dart';
import '../datasources/uc02_remote_datasource.dart';

/// Processes the UC02 offline action queue in chronological order.
///
/// Called:
/// - On connectivity-restored events (from [AlertsProvider])
/// - On app start/resume
/// - When the ranger taps "Sync now"
///
/// Per-action result handling:
/// - `APPLIED`  → mark SYNCED
/// - `DUPLICATE` → mark SYNCED (idempotent; backend already has it)
/// - `REJECTED`  → mark FAILED with a ranger-friendly reason (no internal
///                 words like "conflict" or "server version")
///
/// Network failures increment the retry counter and leave status PENDING
/// for the next sync cycle. Actions with ≥ [maxRetries] failures are
/// marked FAILED to prevent infinite queuing.
class Uc02SyncService {
  final AlertActionRepository _actionRepo;
  final Uc02RemoteDataSource _remote;
  final String? Function() _tokenGetter;

  static const int _maxRetries = 5;

  Uc02SyncService({
    required AlertActionRepository actionRepo,
    required Uc02RemoteDataSource remote,
    required String? Function() tokenGetter,
  })  : _actionRepo = actionRepo,
        _remote = remote,
        _tokenGetter = tokenGetter;

  /// Returns the number of queued PENDING actions.
  Future<int> getPendingCount() => _actionRepo.getPendingCount();

  /// Drains the queue in chronological order, submitting all PENDING actions
  /// to [POST /api/sync].  Returns the number of actions processed.
  Future<int> syncNow() async {
    final token = _tokenGetter();
    if (token == null || token.isEmpty) {
      debugPrint('[UC02 Sync] No token — skipping sync');
      return 0;
    }

    final pending = await _actionRepo.getPendingActions();
    if (pending.isEmpty) {
      debugPrint('[UC02 Sync] Queue empty — nothing to sync');
      return 0;
    }

    debugPrint('[UC02 Sync] Sending ${pending.length} action(s) to /api/sync');

    try {
      final batchResponse = await _remote.syncBatch(pending, token);
      return await _processResults(pending, batchResponse);
    } catch (e) {
      // Network-level failure — increment retries, do not lose data
      debugPrint('[UC02 Sync] Network error during batch: $e');
      for (final action in pending) {
        await _handleNetworkFailure(action);
      }
      return 0;
    }
  }

  Future<int> _processResults(
    List<AlertAction> sent,
    Map<String, dynamic> batchResponse,
  ) async {
    final rawResults = batchResponse['results'] as List<dynamic>? ?? [];
    int processed = 0;

    for (final rawResult in rawResults) {
      final result = rawResult as Map<String, dynamic>;
      final clientActionId = result['clientActionId'] as String?;
      final status = result['status'] as String?;
      final rawReason = result['reason'] as String?;

      if (clientActionId == null) continue;

      switch (status) {
        case 'APPLIED':
          await _actionRepo.markSynced(clientActionId);
          debugPrint('[UC02 Sync] $clientActionId → APPLIED (synced)');
          processed++;
          break;

        case 'DUPLICATE':
          await _actionRepo.markSynced(clientActionId);
          debugPrint('[UC02 Sync] $clientActionId → DUPLICATE (treated as synced)');
          processed++;
          break;

        case 'REJECTED':
          final friendlyReason = _friendlyRejectionReason(rawReason);
          await _actionRepo.markFailed(clientActionId, friendlyReason);
          debugPrint('[UC02 Sync] $clientActionId → REJECTED: $friendlyReason');
          break;

        default:
          debugPrint('[UC02 Sync] $clientActionId → unknown status: $status');
      }
    }

    return processed;
  }

  Future<void> _handleNetworkFailure(AlertAction action) async {
    await _actionRepo.incrementRetry(action.clientActionId);
    if (action.retryCount + 1 >= _maxRetries) {
      await _actionRepo.markFailed(
        action.clientActionId,
        'Could not reach the server after several attempts. Please check your connection.',
      );
      debugPrint(
        '[UC02 Sync] ${action.clientActionId} exceeded max retries — marked FAILED',
      );
    }
  }

  /// Maps technical rejection reasons from the backend into ranger-friendly
  /// messages. Never exposes words like "conflict" or "server version".
  String _friendlyRejectionReason(String? serverReason) {
    if (serverReason == null) {
      return 'This action could not be completed. The alert may have changed.';
    }
    final lower = serverReason.toLowerCase();
    if (lower.contains('reassign') || lower.contains('assign')) {
      return 'This alert was reassigned to another ranger.';
    }
    if (lower.contains('status') || lower.contains('state')) {
      return 'This action is no longer valid — the alert status has changed.';
    }
    if (lower.contains('access') || lower.contains('denied') || lower.contains('permission')) {
      return 'You are not authorised to perform this action.';
    }
    if (lower.contains('not found') || lower.contains('404')) {
      return 'This alert no longer exists on the server.';
    }
    return 'This action could not be completed. Please contact base.';
  }
}
