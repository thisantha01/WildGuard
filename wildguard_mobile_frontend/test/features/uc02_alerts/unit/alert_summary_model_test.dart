import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/entities/alert_summary.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/threat_level.dart';

void main() {
  group('AlertSummary Unit Tests', () {
    final testJson = {
      'id': 'alt-101',
      'displayCode': 'ALT-2026-001',
      'animalName': 'Raja',
      'animalTag': 'ELE-042',
      'species': 'Asian Elephant',
      'zoneName': 'Block A Buffer',
      'zoneType': 'BUFFER',
      'lat': 6.3721,
      'lng': 81.4012,
      'breachTime': '2026-10-09T10:30:00.000Z',
      'threatLevel': 'HIGH',
      'status': 'NOTIFIED',
      'approximateLocation': false,
    };

    test('AlertSummary.fromJson parses all fields correctly', () {
      final summary = AlertSummary.fromJson(testJson);

      expect(summary.id, 'alt-101');
      expect(summary.displayCode, 'ALT-2026-001');
      expect(summary.animalName, 'Raja');
      expect(summary.animalTag, 'ELE-042');
      expect(summary.species, 'Asian Elephant');
      expect(summary.zoneName, 'Block A Buffer');
      expect(summary.zoneType, 'BUFFER');
      expect(summary.lat, 6.3721);
      expect(summary.lng, 81.4012);
      expect(summary.threatLevel, ThreatLevel.high);
      expect(summary.status, AlertStatus.notified);
      expect(summary.approximateLocation, isFalse);
    });

    test('AlertSummary toMap and fromMap SQLite roundtrip', () {
      final summary = AlertSummary.fromJson(testJson);
      final map = summary.toMap();

      expect(map['id'], 'alt-101');
      expect(map['display_code'], 'ALT-2026-001');
      expect(map['threat_level'], 'HIGH');
      expect(map['status'], 'NOTIFIED');
      expect(map['approximate_location'], 0);

      final restored = AlertSummary.fromMap(map);
      expect(restored.id, summary.id);
      expect(restored.displayCode, summary.displayCode);
      expect(restored.animalName, summary.animalName);
      expect(restored.lat, summary.lat);
      expect(restored.lng, summary.lng);
      expect(restored.threatLevel, summary.threatLevel);
      expect(restored.status, summary.status);
    });

    test('AlertSummary copyWith modifies status optimistically', () {
      final summary = AlertSummary.fromJson(testJson);
      final updated = summary.copyWith(status: AlertStatus.acknowledged);

      expect(updated.status, AlertStatus.acknowledged);
      expect(updated.id, summary.id);
      expect(updated.animalName, summary.animalName);
      expect(summary.status, AlertStatus.notified); // Immutability check
    });
  });
}
