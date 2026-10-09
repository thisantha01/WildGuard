import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/constants/uc02_constants.dart';
import 'package:wildguard_mobile_frontend/features/uc02_alerts/presentation/widgets/offline_banner.dart';

void main() {
  group('OfflineBanner Widget Tests', () {
    testWidgets('Renders nothing when isOnline is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(isOnline: true),
          ),
        ),
      );

      expect(find.text(Uc02Constants.offlineBannerText), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });

    testWidgets('Renders high-visibility amber banner with wifi_off icon when isOnline is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(isOnline: false),
          ),
        ),
      );

      expect(find.text(Uc02Constants.offlineBannerText), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });
}
