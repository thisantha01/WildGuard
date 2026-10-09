import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/action_type.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/crop_damage.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/injury_severity.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/threat_level.dart';

void main() {
  group('UC02 Enums & Lifecycle Tests', () {
    test('AlertStatus fromJson and toJson lifecycle mapping', () {
      final statuses = [
        'NEW',
        'NOTIFIED',
        'ACKNOWLEDGED',
        'IN_PROGRESS',
        'PENDING_RESOLUTION',
        'RESOLVED',
        'ESCALATED',
        'DELIVERY_FAILED',
      ];

      for (final s in statuses) {
        final parsed = AlertStatus.fromJson(s);
        expect(parsed.toJson(), s);
        expect(parsed.displayLabel.isNotEmpty, isTrue);
      }
    });

    test('ThreatLevel parses and provides correct styling', () {
      expect(ThreatLevel.fromJson('HIGH'), ThreatLevel.high);
      expect(ThreatLevel.fromJson('MODERATE'), ThreatLevel.moderate);
      expect(ThreatLevel.fromJson('LOW'), ThreatLevel.low);
      expect(ThreatLevel.fromJson(null), ThreatLevel.low);

      expect(ThreatLevel.high.toJson(), 'HIGH');
      expect(ThreatLevel.high.displayLabel, 'HIGH');
    });

    test('CropDamage parses all values correctly', () {
      expect(CropDamage.fromJson('NONE'), CropDamage.none);
      expect(CropDamage.fromJson('MINOR'), CropDamage.minor);
      expect(CropDamage.fromJson('MAJOR'), CropDamage.major);
      expect(CropDamage.fromJson('UNKNOWN'), CropDamage.none);

      expect(CropDamage.major.toJson(), 'MAJOR');
    });

    test('InjurySeverity parses all values correctly', () {
      expect(InjurySeverity.fromJson('NONE'), InjurySeverity.none);
      expect(InjurySeverity.fromJson('HUMAN'), InjurySeverity.human);
      expect(InjurySeverity.fromJson('ANIMAL'), InjurySeverity.animal);
      expect(InjurySeverity.fromJson('UNKNOWN'), InjurySeverity.none);

      expect(InjurySeverity.human.toJson(), 'HUMAN');
    });

    test('ActionType parses wire names correctly', () {
      expect(ActionType.fromJson('ACKNOWLEDGE'), ActionType.acknowledge);
      expect(ActionType.fromJson('DECLINE'), ActionType.decline);
      expect(ActionType.fromJson('CONFIRM_DISPATCH'), ActionType.confirmDispatch);
      expect(ActionType.fromJson('ARRIVED'), ActionType.arrived);
      expect(ActionType.fromJson('FIELD_REPORT'), ActionType.fieldReport);

      expect(ActionType.confirmDispatch.toJson(), 'CONFIRM_DISPATCH');
    });
  });
}
