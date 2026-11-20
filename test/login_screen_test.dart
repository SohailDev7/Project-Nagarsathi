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

    // Theme toggle button exists in top right
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Tap theme toggle button
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Switched to dark mode
    expect(controller.value, ThemeMode.dark);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);

    // Tap theme toggle button again
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    // Switched back to light mode
    expect(controller.value, ThemeMode.light);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
  });

  testWidgets('staff portal link is at the bottom section and navigates', (
    tester,
  ) async {
    disableAnimations(tester);
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    // Bottom section contains staff portal link
    expect(find.text('Are you municipality staff? '), findsOneWidget);
    final staffPortal = find.text('Staff portal');
    expect(staffPortal, findsOneWidget);

    await tester.ensureVisible(staffPortal);
    await tester.pumpAndSettle();
    await tester.tap(staffPortal);
    await tester.pumpAndSettle();

    expect(find.byType(StaffLoginScreen), findsOneWidget);
  });

  testWidgets('email account check is blocked when Firebase is unavailable', (
    tester,
  ) async {
    disableAnimations(tester);
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'new.citizen@nagarsathi.app',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Firebase is not connected. Account verification is unavailable.',
      ),
      findsOneWidget,
    );
    expect(find.text('Password'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('stepped sign-in does not bypass Firebase', (tester) async {
    disableAnimations(tester);
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    // Step 0: only identifier field
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'citizen@nagarsathi.app',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Firebase is not connected. Account verification is unavailable.',
      ),
      findsOneWidget,
    );
    expect(find.text('Password'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Email or phone'), findsOneWidget);
  });

  testWidgets('sign-up password Continue validates the password form', (
    tester,
  ) async {
    disableAnimations(tester);
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Sita Sharma');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'citizen@nagarsathi.app',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Secure your account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'password123');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Check both passwords and try once more.'), findsNothing);
    expect(find.text('Accept the terms to continue.'), findsOneWidget);
  });
}
