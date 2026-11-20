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

  testWidgets('email not found shows inline banner with Sign up link', (
    tester,
  ) async {
    disableAnimations(tester);
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    // In demo mode, 'new.' prefix simulates unregistered account
    await tester.enterText(
      find.byType(TextFormField).first,
      'new.citizen@nagarsathi.app',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify inline banner
    expect(find.text('No account found with this email.'), findsOneWidget);
    final signUpLink = find.widgetWithText(TextButton, 'Sign up').first;
    expect(signUpLink, findsOneWidget);

    await tester.tap(signUpLink);
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets(
    'stepped flow slides to password and supports try another way with OTP',
    (tester) async {
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Step 1: Password field and Try another way button
      expect(find.text('citizen@nagarsathi.app'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Try another way'), findsOneWidget);

      // Open Try another way bottom sheet
      await tester.tap(find.text('Try another way'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in another way'), findsOneWidget);
      expect(find.text('Use password'), findsOneWidget);
      expect(find.text('Get OTP via email'), findsOneWidget);

      // Select Get OTP via email
      await tester.tap(find.text('Get OTP via email'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Now on OTP input mode
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('Verify & sign in'), findsOneWidget);

      // Try another way to switch back to password
      await tester.tap(find.text('Try another way'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use password'));
      await tester.pumpAndSettle();

      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      // Back to email step via Change button
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Email or phone'), findsOneWidget);
    },
  );
}
