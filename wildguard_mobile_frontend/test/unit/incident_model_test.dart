import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/models/incident_model.dart';
import 'package:wildguard_mobile_frontend/models/incident_severity.dart';
import 'package:wildguard_mobile_frontend/models/incident_type.dart';
import 'package:wildguard_mobile_frontend/models/sync_status.dart';

void main() {
  group('IncidentModel Unit Tests', () {
    final testDate = DateTime(2026, 10, 7, 12, 0, 0);

    final model = IncidentModel(
      localIncidentId: 'loc-test-123',
      serverIncidentId: 'srv-mongo-456',
      rangerId: 'ranger-007',
      type: IncidentType.snare,
      severity: IncidentSeverity.critical,
      description: 'Active wire snare near river crossing',
      latitude: 6.3685,
      longitude: 81.5273,
      photoPath: '/storage/photos/snare.jpg',
      photoBase64: 'data:image/jpeg;base64,samplebase64',
      timestamp: testDate,
      syncStatus: SyncStatus.pending,
      syncedAt: null,
      duplicateFlag: false,
    );

    test('toMap should serialize properly for SQLite', () {
      final map = model.toMap();

      expect(map['local_incident_id'], 'loc-test-123');
      expect(map['server_incident_id'], 'srv-mongo-456');
      expect(map['type'], 'SNARE');
      expect(map['severity'], 'CRITICAL');
      expect(map['description'], 'Active wire snare near river crossing');
      expect(map['latitude'], 6.3685);
      expect(map['longitude'], 81.5273);
      expect(map['sync_status'], 'PENDING');
      expect(map['duplicate_flag'], 0);
    });

    test('fromMap should deserialize correctly from SQLite row', () {
      final map = {
        'local_incident_id': 'loc-test-123',
        'server_incident_id': 'srv-mongo-456',
        'ranger_id': 'ranger-007',
        'type': 'SNARE',
        'severity': 'CRITICAL',
        'description': 'Active wire snare near river crossing',
        'latitude': 6.3685,
        'longitude': 81.5273,
        'photo_path': '/storage/photos/snare.jpg',
        'photo_base64': 'data:image/jpeg;base64,samplebase64',
        'timestamp': testDate.toIso8601String(),
        'sync_status': 'PENDING',
        'synced_at': null,
        'duplicate_flag': 0,
      };

      final restored = IncidentModel.fromMap(map);

      expect(restored.localIncidentId, 'loc-test-123');
      expect(restored.type, IncidentType.snare);
      expect(restored.severity, IncidentSeverity.critical);
      expect(restored.latitude, 6.3685);
      expect(restored.longitude, 81.5273);
      expect(restored.syncStatus, SyncStatus.pending);
      expect(restored.duplicateFlag, false);
    });

    test('toApiPayload should format JSON matching Spring Boot backend', () {
      final payload = model.toApiPayload();

      expect(payload['localIncidentId'], 'loc-test-123');
      expect(payload['type'], 'SNARE');
      expect(payload['severity'], 'CRITICAL');
      expect(payload['description'], 'Active wire snare near river crossing');
      expect(payload['latitude'], 6.3685);
      expect(payload['longitude'], 81.5273);
      expect(payload['photoBase64'], 'data:image/jpeg;base64,samplebase64');
      expect(payload['timestamp'], isNotNull);
    });
  });
}
