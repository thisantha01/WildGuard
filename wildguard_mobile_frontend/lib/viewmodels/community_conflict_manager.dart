import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/community_alert_post.dart';
import '../models/community_conflict_report.dart';
import '../models/incident_model.dart';
import '../repositories/community_conflict_repository.dart';

class CommunityConflictManager extends ChangeNotifier {
  final CommunityConflictRepository repository;
  CommunityConflictManager({required this.repository});
  List<CommunityConflictReport> _reports = [];
  List<CommunityAlertPost> _alerts = [];
  bool _loading = false;
  List<CommunityConflictReport> get reports => List.unmodifiable(_reports);
  List<CommunityAlertPost> get alerts => List.unmodifiable(_alerts);
  bool get isLoading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final values = await Future.wait([
        repository.reports(),
        repository.alerts(),
      ]);
      _reports = values[0] as List<CommunityConflictReport>;
      _alerts = values[1] as List<CommunityAlertPost>;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> submitIncident(
    IncidentModel incident, {
    required String reporterName,
    String? reporterPhone,
    String zone = 'Community area',
  }) async {
    final report = CommunityConflictReport(
      id: incident.localIncidentId,
      reporterName: reporterName,
      type: incident.type.displayName,
      description: incident.description,
      zone: zone,
      channel: 'MOBILE_APP',
      latitude: incident.latitude,
      longitude: incident.longitude,
      severity:
          ThreatSeverity.values[incident.severity.index.clamp(0, 3).toInt()],
      status: ConflictReportStatus.pendingSync,
      createdAt: incident.timestamp,
      reporterPhone: reporterPhone,
      photoBase64: incident.photoBase64,
    );
    await repository.saveReport(report);
    _replace(report);
  }

  Future<void> updateStatus(
    CommunityConflictReport report,
    ConflictReportStatus status, {
    String? notes,
    String? unit,
    String? priority,
    String? instructions,
  }) async {
    const transitions = <ConflictReportStatus, Set<ConflictReportStatus>>{
      ConflictReportStatus.pendingSync: {ConflictReportStatus.verified},
      ConflictReportStatus.unverified: {
        ConflictReportStatus.verified,
        ConflictReportStatus.rejected,
        ConflictReportStatus.duplicate,
      },
      ConflictReportStatus.verified: {
        ConflictReportStatus.inProgress,
        ConflictReportStatus.resolved,
        ConflictReportStatus.rejected,
        ConflictReportStatus.duplicate,
      },
      ConflictReportStatus.inProgress: {
        ConflictReportStatus.resolved,
        ConflictReportStatus.verified,
      },
      ConflictReportStatus.resolved: {},
      ConflictReportStatus.duplicate: {},
      ConflictReportStatus.rejected: {},
    };
    if (status != report.status &&
        !(transitions[report.status]?.contains(status) ?? false)) {
      throw ArgumentError(
        'This report cannot move from ${report.status.label} to ${status.label}.',
      );
    }
    if (status == ConflictReportStatus.inProgress &&
        (unit == null || unit.isEmpty)) {
      throw ArgumentError('Select a ranger unit before dispatch.');
    }
    if (status == ConflictReportStatus.inProgress &&
        (priority == null ||
            priority.isEmpty ||
            instructions == null ||
            instructions.trim().isEmpty)) {
      throw ArgumentError(
        'Select dispatch priority and enter tactical instructions.',
      );
    }
    if ((status == ConflictReportStatus.rejected ||
            status == ConflictReportStatus.duplicate) &&
        (notes == null || notes.trim().isEmpty)) {
      throw ArgumentError('Add CLO notes before closing this report.');
    }
    final updated = report.copyWith(
      status: status,
      cloNotes: notes,
      rangerUnit: unit,
      dispatchPriority: priority,
      dispatchInstructions: instructions,
    );
    await repository.saveReport(updated);
    _replace(updated);
    if (status == ConflictReportStatus.verified ||
        status == ConflictReportStatus.inProgress) {
      await publishAlert(updated, notes: notes);
    }
  }

  Future<void> publishAlert(
    CommunityConflictReport report, {
    String? notes,
  }) async {
    final advisory =
        (notes ??
                'Wildlife activity reported nearby. Keep a safe distance and contact local authorities if needed.')
            .trim();
    if (advisory.isEmpty) {
      throw ArgumentError('Safety advisory is required.');
    }
    final alert = CommunityAlertPost(
      id: 'alert-${report.id}',
      title: report.type,
      severity: report.severity.code,
      zone: report.zone,
      advisory: advisory,
      latitude: report.latitude,
      longitude: report.longitude,
      publishedAt: DateTime.now(),
      rangerEnRoute: report.status == ConflictReportStatus.inProgress,
    );
    await repository.saveAlert(alert);
    _alerts = [..._alerts.where((a) => a.id != alert.id), alert];
    notifyListeners();
  }

  Future<void> createBroadcast({
    required String title,
    required String zone,
    required String advisory,
    required ThreatSeverity severity,
  }) async {
    if (title.trim().isEmpty ||
        zone.trim().isEmpty ||
        advisory.trim().isEmpty) {
      throw ArgumentError(
        'Title, village zone, and safety advisory are required.',
      );
    }
    final alert = CommunityAlertPost(
      id: 'alert-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
      title: title.trim(),
      severity: severity.code,
      zone: zone.trim(),
      advisory: advisory.trim(),
      latitude: 0,
      longitude: 0,
      publishedAt: DateTime.now(),
    );
    await repository.saveAlert(alert);
    _alerts = [..._alerts, alert];
    notifyListeners();
  }

  Future<void> resolveAlert(CommunityAlertPost alert) async {
    final a = CommunityAlertPost(
      id: alert.id,
      title: alert.title,
      severity: alert.severity,
      zone: alert.zone,
      advisory: alert.advisory,
      latitude: alert.latitude,
      longitude: alert.longitude,
      publishedAt: alert.publishedAt,
      rangerEnRoute: false,
      resolved: true,
    );
    await repository.saveAlert(a);
    _alerts = [..._alerts.where((x) => x.id != a.id), a];
    notifyListeners();
  }

  void _replace(CommunityConflictReport r) {
    _reports = [..._reports.where((x) => x.id != r.id), r];
    notifyListeners();
  }
}
