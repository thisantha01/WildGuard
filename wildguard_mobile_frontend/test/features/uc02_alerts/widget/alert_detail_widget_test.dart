import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/entities/alert_detail.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/action_type.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/alert_status.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/domain/enums/threat_level.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/providers/alerts_provider.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/screens/alert_detail_screen.dart';

class MockAlertsProvider extends Mock implements AlertsProvider {}

void main() {
  group('AlertDetailScreen Widget Tests', () {
    late MockAlertsProvider mockProvider;

    final notifiedDetail = AlertDetail(
      id: 'alt-777',
      displayCode: 'ALT-2026-077',
      animalName: 'Chandi',
      species: 'Asian Elephant',
      collarCode: 'CLR-99',
      collarBattery: 88,
      collarStatus: 'ACTIVE',
      zoneName: 'Block C Perimeter',
      lat: 6.35,
      lng: 81.42,
      breachTime: DateTime.now(),
      threatLevel: ThreatLevel.high,
      status: AlertStatus.notified,
      nearestVillageName: 'Kataragama Outskirts',
      distanceToVillageM: 250,
      distanceToRangerKm: 1.8,
      etaMinutes: 6,
      safetyInstructions: 'Deploy flashbangs only if breach exceeds buffer zone.',
      approximateLocation: false,
      availableActions: ['ACKNOWLEDGE', 'DECLINE'],
    );

    setUpAll(() {
      registerFallbackValue(ActionType.acknowledge);
    });

    setUp(() {
      mockProvider = MockAlertsProvider();
      when(() => mockProvider.detailState).thenReturn(AlertsLoadState.loaded);
      when(() => mockProvider.currentDetail).thenReturn(notifiedDetail);
      when(() => mockProvider.isOnline).thenReturn(true);
      when(() => mockProvider.isActionInFlight(any(), any())).thenReturn(false);
      when(() => mockProvider.loadAlertDetail(any())).thenAnswer((_) async {});
    });

    testWidgets('Renders telemetry, safety instructions, and ACKNOWLEDGE/DECLINE buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AlertsProvider>.value(
            value: mockProvider,
            child: const AlertDetailScreen(alertId: 'alt-777'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header info
      expect(find.text('Chandi'), findsOneWidget);
      expect(find.textContaining('Kataragama Outskirts'), findsOneWidget);
      expect(find.textContaining('Deploy flashbangs only if breach exceeds buffer zone.'), findsOneWidget);

      // Check action buttons for NOTIFIED status
      expect(find.widgetWithText(ElevatedButton, 'ACKNOWLEDGE'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'CANNOT RESPOND'), findsOneWidget);

      // Check full collar details are rendered directly without dropdown
      expect(find.text('Collar details'), findsOneWidget);
      expect(find.text('CLR-99'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
    });

    testWidgets('Resolved alert hides CONTINUE TO NAVIGATION button and shows full details', (WidgetTester tester) async {
      final resolvedDetail = AlertDetail(
        id: 'alt-888',
        displayCode: 'ALT-2026-088',
        animalName: 'Rajah',
        species: 'Sri Lankan elephant',
        collarCode: 'CLR-101',
        collarBattery: 92,
        collarStatus: 'ACTIVE',
        zoneName: 'Yala Sector 04',
        lat: 6.35,
        lng: 81.42,
        breachTime: DateTime.now(),
        threatLevel: ThreatLevel.high,
        status: AlertStatus.resolved,
        nearestVillageName: 'Ihatikulama',
        distanceToVillageM: 600,
        distanceToRangerKm: 4.8,
        etaMinutes: 14,
        safetyInstructions: '',
        approximateLocation: false,
        availableActions: [],
      );

      when(() => mockProvider.currentDetail).thenReturn(resolvedDetail);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AlertsProvider>.value(
            value: mockProvider,
            child: const AlertDetailScreen(alertId: 'alt-888'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CONTINUE TO NAVIGATION button must NOT be present
      expect(find.text('CONTINUE TO NAVIGATION'), findsNothing);

      // ALERT RESOLVED indicator is shown
      expect(find.text('ALERT RESOLVED'), findsOneWidget);

      // Collar details are directly displayed
      expect(find.text('CLR-101'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
    });
  });
}
