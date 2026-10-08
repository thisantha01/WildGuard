import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_alert_post.dart';
import '../models/community_conflict_report.dart';
import '../services/api_service.dart';

abstract interface class CommunityConflictRepository {
  Future<List<CommunityConflictReport>> reports();
  Future<List<CommunityAlertPost>> alerts();
  Future<void> saveReport(CommunityConflictReport report);
  Future<void> saveAlert(CommunityAlertPost alert);
}

class LocalFirstCommunityConflictRepository
    implements CommunityConflictRepository {
  final ApiService api;
  LocalFirstCommunityConflictRepository(this.api);
  static const _reportsKey = 'wg_community_reports',
      _alertsKey = 'wg_community_alerts';
  Future<List<Map<String, dynamic>>> _read(String key) async {
    final p = await SharedPreferences.getInstance();
    return (jsonDecode(p.getString(key) ?? '[]') as List)
        .cast<Map<String, dynamic>>();
  }

  Future<void> _write(String key, List<Map<String, dynamic>> rows) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(rows));
  }

  @override
  Future<List<CommunityConflictReport>> reports() async {
    final local = await _read(_reportsKey);
    try {
      for (final pending in local.where((e) => e['status'] == 'PENDING_SYNC')) {
        await api.client
            .post(
              Uri.parse('${api.baseUrl}/v1/community-reports'),
              headers: api.authHeaders,
              body: jsonEncode(pending),
            )
            .timeout(const Duration(seconds: 5));
      }
      final r = await api.client
          .get(
            Uri.parse('${api.baseUrl}/v1/community-reports'),
            headers: api.authHeaders,
          )
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final remote = (jsonDecode(r.body) as List)
            .cast<Map<String, dynamic>>();
        final byId = {for (final row in remote) row['id']: row};
        for (final row in local) {
          if (row['status'] == 'PENDING_SYNC') {
            byId.putIfAbsent(row['id'], () => {...row, 'status': 'UNVERIFIED'});
          }
        }
        final merged = byId.values.toList();
        await _write(_reportsKey, merged);
        return merged.map(CommunityConflictReport.fromJson).toList();
      }
    } catch (_) {}
    return local.map(CommunityConflictReport.fromJson).toList();
  }

  @override
  Future<List<CommunityAlertPost>> alerts() async {
    try {
      final r = await api.client
          .get(
            Uri.parse('${api.baseUrl}/v1/community-reports/alerts'),
            headers: api.authHeaders,
          )
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final rows = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        final local = await _read(_alertsKey);
        final byId = {for (final row in rows) row['id']: row};
        for (final row in local) {
          byId.putIfAbsent(row['id'], () => row);
        }
        final merged = byId.values.toList();
        await _write(_alertsKey, merged);
        return merged.map(CommunityAlertPost.fromJson).toList();
      }
    } catch (_) {}
    return (await _read(_alertsKey)).map(CommunityAlertPost.fromJson).toList();
  }

  @override
  Future<void> saveReport(CommunityConflictReport report) async {
    final rows = await _read(_reportsKey);
    rows.removeWhere((e) => e['id'] == report.id);
    rows.add(report.toJson());
    await _write(_reportsKey, rows);
    try {
      await api.client
          .post(
            Uri.parse('${api.baseUrl}/v1/community-reports'),
            headers: api.authHeaders,
            body: jsonEncode(report.toJson()),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  @override
  Future<void> saveAlert(CommunityAlertPost alert) async {
    final rows = await _read(_alertsKey);
    rows.removeWhere((e) => e['id'] == alert.id);
    rows.add(alert.toJson());
    await _write(_alertsKey, rows);
    try {
      await api.client
          .post(
            Uri.parse('${api.baseUrl}/v1/community-reports/alerts'),
            headers: api.authHeaders,
            body: jsonEncode(alert.toJson()),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
