import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/models/community_alert_post.dart';
import 'package:wildguard_mobile_frontend/models/community_conflict_report.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/incident_type.dart';
import 'package:wildguard_mobile_frontend/repositories/community_conflict_repository.dart';
import 'package:wildguard_mobile_frontend/viewmodels/community_conflict_manager.dart';

class MemoryCommunityRepository implements CommunityConflictRepository {
  final List<CommunityConflictReport> savedReports = [];
  final List<CommunityAlertPost> savedAlerts = [];
  @override
  Future<List<CommunityConflictReport>> reports() async => savedReports;
  @override
  Future<List<CommunityAlertPost>> alerts() async => savedAlerts;
  @override
  Future<void> saveReport(CommunityConflictReport report) async {
    savedReports.removeWhere((r) => r.id == report.id);
    savedReports.add(report);
  }

  @override
  Future<void> saveAlert(CommunityAlertPost alert) async {
    savedAlerts.removeWhere((a) => a.id == alert.id);
    savedAlerts.add(alert);
  }
}

CommunityConflictReport sampleReport() => CommunityConflictReport(
  id: 'report-1',
  reporterName: 'Resident',
  type: 'Elephant sighting',
  description: 'Elephant near homes',
  zone: 'North sector',
  channel: 'MOBILE_APP',
  latitude: 6.3,
  longitude: 81.4,
  severity: ThreatSeverity.high,
  status: ConflictReportStatus.unverified,
  createdAt: DateTime.utc(2026),
);

void main() {
  late MemoryCommunityRepository repository;
  late CommunityConflictManager manager;
  setUp(() {
    repository = MemoryCommunityRepository();
    manager = CommunityConflictManager(repository: repository);
  });
  tearDown(() => manager.dispose());

  test('villager incident is added to submitted report status list', () async {
    final incident = IncidentModel(
      localIncidentId: 'local-1',
      type: IncidentType.other,
      severity: IncidentSeverity.high,
      description: 'Wildlife by village',
      latitude: 6.3,
      longitude: 81.4,
      timestamp: DateTime.utc(2026),
    );
    await manager.submitIncident(incident, reporterName: 'Resident');
    expect(manager.reports.single.id, 'local-1');
    expect(manager.reports.single.status, ConflictReportStatus.pendingSync);
  });

  test(
    'CLO verification publishes an alert and dispatch updates report status',
    () async {
      final report = sampleReport();
      await manager.updateStatus(
        report,
        ConflictReportStatus.verified,
        notes: 'Keep away from the river path.',
      );
      expect(manager.reports.single.status, ConflictReportStatus.verified);
      expect(manager.alerts.single.advisory, 'Keep away from the river path.');
      await manager.updateStatus(
        manager.reports.single,
        ConflictReportStatus.inProgress,
        unit: 'Alpha Unit - Rapid Response',
        priority: 'P1 - Immediate',
        instructions: 'Secure the north village approach.',
      );
      expect(manager.reports.single.rangerUnit, 'Alpha Unit - Rapid Response');
      expect(manager.alerts.single.rangerEnRoute, isTrue);
    },
  );

  test(
    'dispatch requires a unit and rejected reports require CLO notes',
    () async {
      await expectLater(
        manager.updateStatus(
          sampleReport().copyWith(status: ConflictReportStatus.verified),
          ConflictReportStatus.inProgress,
        ),
        throwsArgumentError,
      );
      final verified = sampleReport().copyWith(
        status: ConflictReportStatus.verified,
      );
      await expectLater(
        manager.updateStatus(verified, ConflictReportStatus.rejected),
        throwsArgumentError,
      );
    },
  );
}
