import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/incident_model.dart';

/// Service managing remote HTTP requests to the WildGuard Spring Boot backend.
class ApiService {
  final http.Client client;
  final String baseUrl;
  String? authToken;

  ApiService({
    http.Client? client,
    String? baseUrl,
    this.authToken,
  })  : client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl;

  /// Sets active Ranger JWT authentication token.
  void setAuthToken(String? token) {
    authToken = token;
  }

  /// Authenticates a Ranger against POST /api/auth/login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl${AppConstants.loginEndpoint}');
      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('token')) {
          setAuthToken(data['token'] as String);
        }
        return data;
      } else {
        throw NetworkSyncException(
          'Login failed: Incorrect username or password',
          response.body,
        );
      }
    } on NetworkSyncException {
      rethrow;
    } catch (e) {
      throw NetworkSyncException('Network error during login', e.toString());
    }
  }

  /// Registers a new Ranger against POST /api/auth/register
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? badgeNumber,
    String? assignedPark,
    String role = 'RANGER',
  }) async {
    try {
      final url = Uri.parse('$baseUrl${AppConstants.registerEndpoint}');
      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'email': email.trim(),
              'password': password,
              'fullName': fullName.trim(),
              'badgeNumber': badgeNumber?.trim(),
              'assignedPark': assignedPark?.trim(),
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('token')) {
          setAuthToken(data['token'] as String);
        }
        return data;
      } else {
        throw NetworkSyncException(
          'Registration failed. User or email might already exist.',
          response.body,
        );
      }
    } on NetworkSyncException {
      rethrow;
    } catch (e) {
      throw NetworkSyncException('Network error during registration', e.toString());
    }
  }

  /// Sends a single offline incident to the Spring Boot backend (`/api/incidents/sync`).
  Future<Map<String, dynamic>> syncIncident(IncidentModel incident) async {
    try {
      if (authToken == null || authToken!.isEmpty) {
        throw const NetworkSyncException(
          'Authentication required: Please log in as a Ranger to sync with base station.',
        );
      }

      final url = Uri.parse('$baseUrl${AppConstants.syncEndpoint}');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

      final response = await client
          .post(
            url,
            headers: headers,
            body: jsonEncode(incident.toApiPayload()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        String serverMsg = '';
        try {
          final errData = jsonDecode(response.body) as Map<String, dynamic>;
          serverMsg = errData['message'] as String? ?? '';
        } catch (_) {}
        final msg = serverMsg.isNotEmpty
            ? serverMsg
            : 'Server returned error status: ${response.statusCode}';
        throw NetworkSyncException(
          'Failed to sync incident: $msg',
          response.body,
        );
      }
    } on NetworkSyncException {
      rethrow;
    } catch (e) {
      throw NetworkSyncException('Network error during incident synchronization: $e', e.toString());
    }
  }

  /// Fetches next available badge ID from backend based on role
  Future<String> fetchNextBadgeNumber(String role) async {
    try {
      final url = Uri.parse('$baseUrl${AppConstants.nextBadgeEndpoint}?role=$role');
      final response = await client
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['badgeNumber'] as String? ?? '';
      }
    } catch (_) {
      // Return empty string on network failure/offline so caller can use fallback
    }
    return '';
  }

  /// Fetches logged incident history for the authenticated ranger from GET `/api/incidents/my-history`.
  Future<List<Map<String, dynamic>>> fetchMyIncidentHistory() async {
    try {
      if (authToken == null || authToken!.isEmpty) {
        debugPrint('⚠️ [REMOTE HISTORY] Skipped: authToken is null or empty.');
        return [];
      }
      final url = Uri.parse('$baseUrl${AppConstants.incidentHistoryEndpoint}');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

      final response = await client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        debugPrint('📥 [REMOTE HISTORY] Successfully fetched ${list.length} reports from base station.');
        return list.map((item) => item as Map<String, dynamic>).toList();
      } else {
        debugPrint('⚠️ [REMOTE HISTORY] Server returned status ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ [REMOTE HISTORY ERROR] Failed to fetch remote history: $e');
      return [];
    }
  }
}
