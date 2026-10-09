import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/alert_action.dart';

/// Remote HTTP data source for all UC02 API calls.
/// Reuses the existing [AppConstants.defaultApiBaseUrl] and the app's JWT
/// token (passed in on each call to avoid a tight coupling to [ApiService]).
class Uc02RemoteDataSource {
  final http.Client _client;
  final String _baseUrl;

  Uc02RemoteDataSource({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _parseJson(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    String msg = 'Server error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      msg = body['message'] as String? ?? msg;
    } catch (_) {}
    throw NetworkSyncException(msg, response.body);
  }

  Future<List<dynamic>> _parseJsonList(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    String msg = 'Server error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      msg = body['message'] as String? ?? msg;
    } catch (_) {}
    throw NetworkSyncException(msg, response.body);
  }

  // ─── Alert endpoints ─────────────────────────────────────────────────────

  /// [GET /api/alerts] — fetches the ranger's alert list.
  Future<List<Map<String, dynamic>>> fetchAlerts(String token) async {
    final url = Uri.parse('$_baseUrl/alerts');
    final response = await _client
        .get(url, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));
    final list = await _parseJsonList(response);
    return list.cast<Map<String, dynamic>>();
  }

  /// [GET /api/alerts/{id}] — fetches full alert detail.
  Future<Map<String, dynamic>> fetchAlertDetail(
      String id, String token) async {
    final url = Uri.parse('$_baseUrl/alerts/$id');
    final response = await _client
        .get(url, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));
    return _parseJson(response);
  }

  /// [POST /api/alerts/{id}/acknowledge]
  Future<Map<String, dynamic>> acknowledge(String id, String token) async {
    final url = Uri.parse('$_baseUrl/alerts/$id/acknowledge');
    final response = await _client
        .post(url, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));
    return _parseJson(response);
  }

  /// [POST /api/alerts/{id}/decline]  body: `{ reason }`
  Future<Map<String, dynamic>> decline(
      String id, String reason, String token) async {
    final url = Uri.parse('$_baseUrl/alerts/$id/decline');
    final response = await _client
        .post(
          url,
          headers: _authHeaders(token),
          body: jsonEncode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
    return _parseJson(response);
  }

  /// [POST /api/alerts/{id}/confirm-dispatch]
  Future<Map<String, dynamic>> confirmDispatch(
      String id, String token) async {
    final url = Uri.parse('$_baseUrl/alerts/$id/confirm-dispatch');
    final response = await _client
        .post(url, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));
    return _parseJson(response);
  }

  /// [POST /api/alerts/{id}/arrived]
  Future<Map<String, dynamic>> arrived(String id, String token) async {
    final url = Uri.parse('$_baseUrl/alerts/$id/arrived');
    final response = await _client
        .post(url, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 15));
    return _parseJson(response);
  }

  /// [POST /api/alerts/{id}/field-report]
  Future<Map<String, dynamic>> submitFieldReport(
    String id,
    Map<String, dynamic> body,
    String token,
  ) async {
    final url = Uri.parse('$_baseUrl/alerts/$id/field-report');
    final response = await _client
        .post(
          url,
          headers: _authHeaders(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _parseJson(response);
  }

  // ─── Sync endpoint ────────────────────────────────────────────────────────

  /// [POST /api/sync] — sends the offline action queue batch.
  /// Returns the raw JSON map of [SyncBatchResponse].
  Future<Map<String, dynamic>> syncBatch(
    List<AlertAction> actions,
    String token,
  ) async {
    final url = Uri.parse('$_baseUrl/sync');
    // Note: /api/sync is at baseUrl which already includes /api
    final actionsJson = actions.map((a) {
      return {
        'clientActionId': a.clientActionId,
        'type': a.type.toJson(),
        'alertId': a.alertId,
        'occurredAt': a.occurredAt.toUtc().toIso8601String(),
        'payload': a.payload,
      };
    }).toList();

    final response = await _client
        .post(
          url,
          headers: _authHeaders(token),
          body: jsonEncode({'actions': actionsJson}),
        )
        .timeout(const Duration(seconds: 30));
    return _parseJson(response);
  }

  // ─── Location / Heartbeat ────────────────────────────────────────────────

  /// [PUT /api/rangers/me/location]
  Future<void> updateLocation(
      double lat, double lng, String token) async {
    final url = Uri.parse('$_baseUrl/rangers/me/location');
    // Use PUT — note the base URL is /api, so full path is /api/rangers/me/location
    await _client
        .put(
          url,
          headers: _authHeaders(token),
          body: jsonEncode({'lat': lat, 'lng': lng}),
        )
        .timeout(const Duration(seconds: 10));
    // Ignore response — best effort
  }

  /// [POST /api/rangers/me/heartbeat]
  Future<void> heartbeat(String token) async {
    final url = Uri.parse('$_baseUrl/rangers/me/heartbeat');
    await _client
        .post(url, headers: _authHeaders(token))
        .timeout(const Duration(seconds: 10));
    // Ignore response — best effort
  }
}
