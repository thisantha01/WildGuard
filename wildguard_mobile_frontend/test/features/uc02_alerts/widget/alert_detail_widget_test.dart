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
    });
  });
}
