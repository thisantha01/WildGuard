import '../../domain/entities/alert_detail.dart';
import '../../domain/entities/alert_summary.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/uc02_local_datasource.dart';
import '../datasources/uc02_remote_datasource.dart';

/// Concrete implementation of [AlertRepository].
///
/// Fetch strategy:
/// - Online: fetch from API → upsert cache → return API data.
/// - Offline / network error: return cached data from SQLite.
class AlertRepositoryImpl implements AlertRepository {
  final Uc02RemoteDataSource _remote;
  final Uc02DatabaseHelper _local;
  final String? Function() _tokenGetter;

  AlertRepositoryImpl({
    required Uc02RemoteDataSource remote,
    required Uc02DatabaseHelper local,
    required String? Function() tokenGetter,
  })  : _remote = remote,
        _local = local,
        _tokenGetter = tokenGetter;

  @override
  Future<List<AlertSummary>> getAlerts() async {
    final token = _tokenGetter();
    if (token == null || token.isEmpty) {
      return _local.getCachedAlerts();
    }
    try {
      final jsonList = await _remote.fetchAlerts(token);
      final alerts = jsonList.map(AlertSummary.fromJson).toList();
      await _local.upsertAlerts(alerts);
      return alerts;
    } catch (_) {
      return _local.getCachedAlerts();
    }
  }

  @override
  Future<AlertDetail> getAlertDetail(String id) async {
    final token = _tokenGetter();
    if (token == null || token.isEmpty) {
      return _getCachedDetail(id);
    }
    try {
      final json = await _remote.fetchAlertDetail(id, token);
      await _local.upsertDetailJson(id, Uc02DatabaseHelper.encodeDetail(json));
      return AlertDetail.fromJson(json);
    } catch (_) {
      return _getCachedDetail(id);
    }
  }

  @override
  Future<void> refreshAlerts() async {
    final token = _tokenGetter();
    if (token == null || token.isEmpty) return;
    try {
      final jsonList = await _remote.fetchAlerts(token);
      final alerts = jsonList.map(AlertSummary.fromJson).toList();
      await _local.upsertAlerts(alerts);
    } catch (_) {
      // Silently swallow — UI shows cached data
    }
  }

  Future<AlertDetail> _getCachedDetail(String id) async {
    final raw = await _local.getDetailJson(id);
    if (raw == null) {
      throw Exception('Alert $id not found in local cache and device is offline.');
    }
    final json = Uc02DatabaseHelper.decodeDetail(raw);
    if (json == null) throw Exception('Cached detail for $id is corrupt.');
    return AlertDetail.fromJson(json);
  }
}
