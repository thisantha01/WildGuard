import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wildguard_mobile_frontend/screens/register_screen.dart';
import 'package:wildguard_mobile_frontend/services/api_service.dart';
import 'package:wildguard_mobile_frontend/viewmodels/auth_manager.dart';

void main() {
  Widget createRegisterTestWidget({AuthManager? authManager}) {
    final auth = authManager ?? AuthManager(apiService: ApiService());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthManager>.value(value: auth),
      ],
      child: const MaterialApp(
        home: RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen Role-Based Badge Auto-Assignment Tests', () {
    testWidgets('Renders all registration fields and Register button', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterTestWidget());

      expect(find.text('Join WildGuard Conservation Team'), findsOneWidget);
      expect(find.byKey(const Key('reg_fullname_field')), findsOneWidget);
      expect(find.byKey(const Key('reg_username_field')), findsOneWidget);
      expect(find.byKey(const Key('reg_email_field')), findsOneWidget);
      expect(find.byKey(const Key('reg_password_field')), findsOneWidget);
      expect(find.byKey(const Key('reg_role_field')), findsOneWidget);
      expect(find.byKey(const Key('reg_park_field')), findsOneWidget);
      expect(find.byKey(const Key('reg_badge_field')), findsOneWidget);
      expect(find.text('REGISTER'), findsOneWidget);
    });

    testWidgets('Badge field is read-only and automatically assigned to WG-RNG-001 for RANGER by default', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterTestWidget());

      final badgeFieldFinder = find.byKey(const Key('reg_badge_field'));
      expect(badgeFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(
        find.descendant(of: badgeFieldFinder, matching: find.byType(TextField)),
      );
      expect(textField.readOnly, isTrue);

      expect(find.text('WG-RNG-001'), findsOneWidget);
      expect(find.text('Staff Badge ID (System-Assigned)'), findsOneWidget);
    });

    testWidgets('Changing role dropdown to MANAGER auto-assigns WG-MGR-001', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterTestWidget());

      // Open Role Dropdown
      final roleDropdownFinder = find.byKey(const Key('reg_role_field'));
      await tester.ensureVisible(roleDropdownFinder);
      await tester.tap(roleDropdownFinder);
      await tester.pumpAndSettle();

      // Select MANAGER
      final managerItemFinder = find.text('MANAGER (Park Administration)').last;
      await tester.tap(managerItemFinder);
      await tester.pumpAndSettle();

      // Verify Badge auto-updated to WG-MGR-001
      expect(find.text('WG-MGR-001'), findsOneWidget);
    });

    testWidgets('Changing role dropdown to LIAISON auto-assigns WG-LIA-001', (WidgetTester tester) async {
      await tester.pumpWidget(createRegisterTestWidget());

      // Open Role Dropdown
      final roleDropdownFinder = find.byKey(const Key('reg_role_field'));
      await tester.ensureVisible(roleDropdownFinder);
      await tester.tap(roleDropdownFinder);
      await tester.pumpAndSettle();

      // Select LIAISON
      final liaisonItemFinder = find.text('LIAISON (Community Relations)').last;
      await tester.tap(liaisonItemFinder);
      await tester.pumpAndSettle();

      // Verify Badge auto-updated to WG-LIA-001
      expect(find.text('WG-LIA-001'), findsOneWidget);
    });

    testWidgets('Dynamically loads next available badge (WG-RNG-002) when 001 already exists in database', (WidgetTester tester) async {
      final authManager = AuthManager(apiService: FakeBadgeApiService());
      await tester.pumpWidget(createRegisterTestWidget(authManager: authManager));
      await tester.pumpAndSettle();

      expect(find.text('WG-RNG-002'), findsOneWidget);
    });
  });
}

class FakeBadgeApiService extends ApiService {
  @override
  Future<String> fetchNextBadgeNumber(String role) async {
    if (role == 'RANGER') return 'WG-RNG-002';
    if (role == 'MANAGER') return 'WG-MGR-005';
    return 'WG-LIA-003';
  }
}
