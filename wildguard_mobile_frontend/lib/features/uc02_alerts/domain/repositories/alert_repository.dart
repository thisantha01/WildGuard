import '../entities/alert_summary.dart';
import '../entities/alert_detail.dart';

/// Abstract contract for fetching and caching alerts.
/// Implemented by [AlertRepositoryImpl] in the data layer.
abstract class AlertRepository {
  /// Fetches the ranger's alerts.  
  /// Returns cached data immediately when offline.
  Future<List<AlertSummary>> getAlerts();

  /// Fetches full details for a single alert by [id].
  Future<AlertDetail> getAlertDetail(String id);

  /// Refreshes the local cache from the API.
  /// No-op when offline.
  Future<void> refreshAlerts();
}
