import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/sign_up_screen.dart';
import 'package:projectnagarsathi/screens/staff_login_screen.dart';
import 'package:projectnagarsathi/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  void disableAnimations(WidgetTester tester) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
  }

  testWidgets('top right has theme toggle button that switches theme mode', (
    tester,
  ) async {
    disableAnimations(tester);
    final controller = ThemeController(ThemeMode.light);
    addTearDown(controller.dispose);

    await tester.pumpWidget(NagarSathiApp(themeController: controller));
    await tester.pumpAndSettle();

    // Theme toggle icon exists in top right pill pair
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    // Tap theme toggle
    await tester.tap(find.byKey(const Key('global-theme-toggle')));
    await tester.pumpAndSettle();

    // Switched to dark mode
    expect(controller.value, ThemeMode.dark);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    // Tap theme toggle again
    await tester.tap(find.byKey(const Key('global-theme-toggle')));
    await tester.pumpAndSettle();

    // Switched back to light mode
    expect(controller.value, ThemeMode.light);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
  });

  testWidgets('staff portal pill is at the bottom section and navigates', (
    tester,
  ) async {
    disableAnimations(tester);
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    // Bottom section contains staff portal pill link
    expect(find.text('Are you municipality staff? '), findsOneWidget);
    final staffPortal = find.byKey(const Key('staff-portal-pill'));
    expect(staffPortal, findsOneWidget);

    await tester.ensureVisible(staffPortal);
    await tester.pumpAndSettle();
    await tester.tap(staffPortal);
    await tester.pumpAndSettle();

    expect(find.byType(StaffLoginScreen), findsOneWidget);
  });

  testWidgets(
    'single-screen sign-in shows email and password immediately and blocks when Firebase is unavailable',
    (tester) async {
      disableAnimations(tester);
      await tester.pumpWidget(const NagarSathiApp());
      await tester.pumpAndSettle();

      // Both identifier and password fields are immediately visible
      expect(find.byType(TextFormField), findsNWidgets(2));

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'citizen@nagarsathi.app',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Firebase is not connected. Sign-in is unavailable.'),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets(
    'sign-up password step shows live checklist and validates terms',
    (tester) async {
      disableAnimations(tester);
      await tester.pumpWidget(const NagarSathiApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sign up'));
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);

      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('8+ characters'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'citizen@nagarsathi.app',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');
      await tester.pumpAndSettle();
      expect(find.text('Strong'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.text('Accept the terms to continue.'),
        findsAtLeastNWidgets(1),
      );
    },
  );
}
