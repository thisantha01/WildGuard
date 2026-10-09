import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/entities/alert_detail.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/threat_level.dart';

void main() {
  group('AlertDetail Unit Tests', () {
    final detailJson = {
      'id': 'alt-202',
      'displayCode': 'ALT-2026-002',
      'animalName': 'Tusker 7',
      'animalTag': 'ELE-007',
      'species': 'Asian Elephant',
      'sex': 'MALE',
      'collarCode': 'CLR-881',
      'collarBattery': 82,
      'collarStatus': 'ACTIVE',
      'zoneName': 'Zone 4 Outer',
      'zoneType': 'AGRICULTURE_BORDER',
      'lat': 6.3812,
      'lng': 81.3920,
      'breachTime': '2026-10-09T08:00:00.000Z',
      'threatLevel': 'MODERATE',
      'status': 'IN_PROGRESS',
      'nearestVillageName': 'Thalgasmote Village',
      'distanceToVillageM': 450.0,
      'distanceToRangerKm': 2.4,
      'etaMinutes': 8,
      'safetyInstructions': 'Maintain 50m standoff distance. Do not shine direct flashlights.',
      'approximateLocation': false,
      'availableActions': ['ARRIVED', 'SUBMIT_FIELD_REPORT'],
      'acknowledgedAt': '2026-10-09T08:05:00.000Z',
      'dispatchConfirmedAt': '2026-10-09T08:07:00.000Z',
    };

    test('AlertDetail.fromJson parses telemetry, village, and timing correctly', () {
      final detail = AlertDetail.fromJson(detailJson);

      expect(detail.id, 'alt-202');
      expect(detail.collarBattery, 82);
      expect(detail.collarStatus, 'ACTIVE');
      expect(detail.nearestVillageName, 'Thalgasmote Village');
      expect(detail.distanceToVillageM, 450.0);
      expect(detail.distanceToRangerKm, 2.4);
      expect(detail.etaMinutes, 8);
      expect(detail.status, AlertStatus.inProgress);
      expect(detail.threatLevel, ThreatLevel.moderate);
      expect(detail.availableActions, contains('ARRIVED'));
      expect(detail.acknowledgedAt, isNotNull);
      expect(detail.dispatchConfirmedAt, isNotNull);
    });

    test('AlertDetail copyWithStatus modifies status and actions correctly', () {
      final detail = AlertDetail.fromJson(detailJson);
      final updated = detail.copyWithStatus(
        AlertStatus.pendingResolution,
        ['SUBMIT_FIELD_REPORT'],
      );

      expect(updated.status, AlertStatus.pendingResolution);
      expect(updated.availableActions, ['SUBMIT_FIELD_REPORT']);
      expect(updated.id, detail.id);
      expect(updated.nearestVillageName, detail.nearestVillageName);
      expect(detail.status, AlertStatus.inProgress);
    });
  });
}
