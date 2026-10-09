import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/location_service.dart';
import '../../data/datasources/uc02_local_datasource.dart';
import '../../data/datasources/uc02_remote_datasource.dart';
import '../../data/repositories/alert_action_repository_impl.dart';
import '../../data/repositories/alert_repository_impl.dart';
import '../../data/services/uc02_location_reporter.dart';
import '../../data/services/uc02_sync_service.dart';
import '../../domain/entities/alert_detail.dart';
import '../../domain/entities/alert_summary.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../constants/uc02_constants.dart';

/// UI-facing load state for list and detail views.
enum AlertsLoadState { idle, loading, loaded, error }

/// Central [ChangeNotifier] for all UC02 Ranger Alert screens.
///
/// Wired together by [buildAlertsProvider] and added to the root
/// [MultiProvider] in `main.dart`.
class AlertsProvider extends ChangeNotifier {
  // ── Dependencies ──────────────────────────────────────────────────────────
  final AlertRepositoryImpl _alertRepo;
  final AlertActionRepositoryImpl _actionRepo;
  final Uc02SyncService _syncService;
  final ConnectivityService _connectivityService;
  final Uc02LocationReporter _locationReporter;

  // ── List state ────────────────────────────────────────────────────────────
  AlertsLoadState _listState = AlertsLoadState.idle;
  List<AlertSummary> _alerts = [];

  // ── Detail state ──────────────────────────────────────────────────────────
  AlertsLoadState _detailState = AlertsLoadState.idle;
  AlertDetail? _currentDetail;

  // ── Shared state ──────────────────────────────────────────────────────────
  String? _errorMessage;
  int _pendingSyncCount = 0;
  bool _isOnline = true;
  bool _isSyncing = false;

  /// Tracks which action types are currently in-flight per alert (for
  /// optimistic overlay indicators).
  final Map<String, List<ActionType>> _inFlightActions = {};

  Timer? _refreshTimer;
  StreamSubscription<bool>? _connectivitySub;

  // ── Constructor ───────────────────────────────────────────────────────────
  AlertsProvider({
    required AlertRepositoryImpl alertRepo,
    required AlertActionRepositoryImpl actionRepo,
    required Uc02SyncService syncService,
    required ConnectivityService connectivityService,
    required Uc02LocationReporter locationReporter,
  })  : _alertRepo = alertRepo,
        _actionRepo = actionRepo,
        _syncService = syncService,
        _connectivityService = connectivityService,
        _locationReporter = locationReporter;

  // ── Getters ───────────────────────────────────────────────────────────────
  AlertsLoadState get listState => _listState;
  AlertsLoadState get detailState => _detailState;
  List<AlertSummary> get alerts => List.unmodifiable(_alerts);
  AlertDetail? get currentDetail => _currentDetail;
  String? get errorMessage => _errorMessage;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  bool isActionInFlight(String alertId, ActionType type) =>
      _inFlightActions[alertId]?.contains(type) ?? false;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Bootstrap — call once in [main.dart] after provider creation.
  Future<void> initialise() async {
    _isOnline = await _connectivityService.isOnline();
    await loadAlerts();
    await _refreshPendingCount();
    _startAutoRefresh();
    _subscribeConnectivity();
    _locationReporter.start();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Uc02Constants.alertsRefreshInterval,
      (_) => _silentRefresh(),
    );
  }

  void _subscribeConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub =
        _connectivityService.onConnectivityChanged.listen((online) async {
      final wasOffline = !_isOnline;
      _isOnline = online;
      notifyListeners();
      if (online && wasOffline) {
        debugPrint('[UC02 Provider] Connectivity restored → sync + refresh');
        await syncNow();
        await _silentRefresh();
      }
    });
  }

  // ── Alert list ────────────────────────────────────────────────────────────

  /// Loads alerts.  Always shows cached data immediately; fetches remote when
  /// online.
  Future<void> loadAlerts() async {
    _listState = AlertsLoadState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _isOnline = await _connectivityService.isOnline();
      _alerts = await _alertRepo.getAlerts();
      _listState = AlertsLoadState.loaded;
    } catch (e) {
      _errorMessage = 'Could not load alerts.';
      _listState = AlertsLoadState.error;
    }
    await _refreshPendingCount();
    notifyListeners();
  }

  Future<void> _silentRefresh() async {
    _isOnline = await _connectivityService.isOnline();
    try {
      _alerts = await _alertRepo.getAlerts();
      await _refreshPendingCount();
      notifyListeners();
    } catch (_) {}
  }

  // ── Alert detail ──────────────────────────────────────────────────────────

  /// Loads full detail for [alertId].
  Future<void> loadAlertDetail(String alertId) async {
    _detailState = AlertsLoadState.loading;
    _currentDetail = null;
    _errorMessage = null;
    notifyListeners();
    try {
      _isOnline = await _connectivityService.isOnline();
      _currentDetail = await _alertRepo.getAlertDetail(alertId);
      _detailState = AlertsLoadState.loaded;
    } catch (e) {
      _errorMessage = 'Could not load alert details.';
      _detailState = AlertsLoadState.error;
    }
    notifyListeners();
  }

  /// Silently re-fetches detail for the currently open alert.
  Future<void> refreshCurrentDetail() async {
    final id = _currentDetail?.id;
    if (id == null) return;
    try {
      _currentDetail = await _alertRepo.getAlertDetail(id);
      notifyListeners();
    } catch (_) {}
  }

  // ── Ranger actions ────────────────────────────────────────────────────────

  /// Executes a ranger action (online → API; offline → queue + optimistic).
  ///
  /// Returns the new [AlertStatus] on success, or `null` if validation failed.
  /// Error messages are surfaced via [errorMessage].
  Future<AlertStatus?> performAction({
    required String alertId,
    required AlertStatus currentStatus,
    required ActionType type,
    Map<String, dynamic> payload = const {},
  }) async {
    _isOnline = await _connectivityService.isOnline();
    _errorMessage = null;

    // Track in-flight for spinner overlay
    (_inFlightActions[alertId] ??= []).add(type);
    notifyListeners();

    try {
      final newStatus = await _actionRepo.performAction(
        alertId: alertId,
        currentStatus: currentStatus,
        type: type,
        payload: payload,
      );

      // Apply optimistic update to summary list
      final idx = _alerts.indexWhere((a) => a.id == alertId);
      if (idx >= 0) {
        _alerts[idx] = _alerts[idx].copyWith(status: newStatus);
      }

      // Apply optimistic update to current detail
      if (_currentDetail?.id == alertId) {
        _currentDetail = _currentDetail!.copyWithStatus(
          newStatus,
          _actionsForStatus(newStatus),
        );
      }

      await _refreshPendingCount();
      return newStatus;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _inFlightActions[alertId]?.remove(type);
      if (_inFlightActions[alertId]?.isEmpty ?? false) {
        _inFlightActions.remove(alertId);
      }
      notifyListeners();
    }
  }

  List<String> _actionsForStatus(AlertStatus status) {
    switch (status) {
      case AlertStatus.notified:
        return ['ACKNOWLEDGE', 'DECLINE'];
      case AlertStatus.acknowledged:
        return ['CONFIRM_DISPATCH'];
      case AlertStatus.inProgress:
        return ['ARRIVED', 'SUBMIT_FIELD_REPORT'];
      case AlertStatus.pendingResolution:
        return ['SUBMIT_FIELD_REPORT'];
      default:
        return [];
    }
  }

  // ── Sync ─────────────────────────────────────────────────────────────────

  /// Manually triggers the offline action queue sync.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    try {
      await _syncService.syncNow();
      await _refreshPendingCount();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      _pendingSyncCount = await _syncService.getPendingCount();
    } catch (_) {}
  }

  // ── Misc ─────────────────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySub?.cancel();
    _locationReporter.stop();
    super.dispose();
  }
}

// ─── Factory ─────────────────────────────────────────────────────────────────

/// Builds a fully-wired [AlertsProvider].  Call this in `main.dart` inside
/// [MultiProvider].
AlertsProvider buildAlertsProvider({
  required String? Function() tokenGetter,
  required bool Function() isOnlineGetter,
  required ConnectivityService connectivityService,
  required LocationService locationService,
}) {
  final localDb = Uc02DatabaseHelper();
  final remote = Uc02RemoteDataSource();

  final alertRepo = AlertRepositoryImpl(
    remote: remote,
    local: localDb,
    tokenGetter: tokenGetter,
  );

  final actionRepo = AlertActionRepositoryImpl(
    remote: remote,
    local: localDb,
    isOnline: isOnlineGetter,
    tokenGetter: tokenGetter,
  );

  final syncService = Uc02SyncService(
    actionRepo: actionRepo,
    remote: remote,
    tokenGetter: tokenGetter,
  );

  final locationReporter = Uc02LocationReporter(
    locationService: locationService,
    connectivityService: connectivityService,
    remote: remote,
    tokenGetter: tokenGetter,
  );

  return AlertsProvider(
    alertRepo: alertRepo,
    actionRepo: actionRepo,
    syncService: syncService,
    connectivityService: connectivityService,
    locationReporter: locationReporter,
  );
}
