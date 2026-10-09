import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/entities/alert_detail.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/threat_level.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/providers/alerts_provider.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/screens/field_report_screen.dart';

class MockAlertsProvider extends Mock implements AlertsProvider {}

void main() {
  group('FieldReportScreen Widget Tests', () {
    late MockAlertsProvider mockProvider;

    final dummyDetail = AlertDetail(
      id: 'alt-555',
      displayCode: 'ALT-2026-055',
      animalName: 'Raja',
      collarCode: 'CLR-01',
      collarBattery: 90,
      collarStatus: 'ACTIVE',
      zoneName: 'Block A',
      lat: 6.37,
      lng: 81.40,
      breachTime: DateTime.now(),
      threatLevel: ThreatLevel.high,
      status: AlertStatus.pendingResolution,
      nearestVillageName: 'Yala Edge',
      distanceToVillageM: 300,
      distanceToRangerKm: 0.1,
      etaMinutes: 0,
      safetyInstructions: 'Maintain distance.',
      approximateLocation: false,
      availableActions: ['SUBMIT_FIELD_REPORT'],
    );

    setUp(() {
      mockProvider = MockAlertsProvider();
      when(() => mockProvider.detailState).thenReturn(AlertsLoadState.loaded);
      when(() => mockProvider.currentDetail).thenReturn(dummyDetail);
      when(() => mockProvider.isOnline).thenReturn(true);
      when(() => mockProvider.loadAlertDetail(any())).thenAnswer((_) async {});
    });

    testWidgets('Submit button is disabled initially, enabled only after situation is safe is toggled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AlertsProvider>.value(
            value: mockProvider,
            child: const FieldReportScreen(alertId: 'alt-555'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the submit button
      final submitFinder = find.widgetWithText(ElevatedButton, 'SUBMIT REPORT');
      expect(submitFinder, findsOneWidget);

      ElevatedButton submitButton = tester.widget<ElevatedButton>(submitFinder);
      expect(submitButton.onPressed, isNull); // Disabled because situationSafe is false

      // Toggle "Situation is safe" switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Submit button should now be enabled
      submitButton = tester.widget<ElevatedButton>(submitFinder);
      expect(submitButton.onPressed, isNotNull);
    });
  });
}
