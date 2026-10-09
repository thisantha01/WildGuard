import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/threat_level.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/widgets/status_chip.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/widgets/threat_badge.dart';

void main() {
  group('ThreatBadge & StatusChip Widget Tests', () {
    testWidgets('ThreatBadge renders icon and text for all threat levels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ThreatBadge(level: ThreatLevel.high),
                ThreatBadge(level: ThreatLevel.moderate),
                ThreatBadge(level: ThreatLevel.low),
              ],
            ),
          ),
        ),
      );

      expect(find.text('HIGH THREAT'), findsOneWidget);
      expect(find.text('MODERATE THREAT'), findsOneWidget);
      expect(find.text('LOW THREAT'), findsOneWidget);
    });

    testWidgets('StatusChip renders icon and label for alert statuses', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusChip(status: AlertStatus.notified),
                StatusChip(status: AlertStatus.inProgress),
                StatusChip(status: AlertStatus.resolved),
              ],
            ),
          ),
        ),
      );

      expect(find.text('NOTIFIED'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
    });
  });
}
