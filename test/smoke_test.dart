import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';

void main() {
  testWidgets('auth flow renders and navigates', (tester) async {
    // The wizard illustration loops forever; honour reduced motion so
    // pumpAndSettle can finish, exactly like a device with animations off.
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    // Switch to phone login.
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    expect(find.text('+977 98XXXXXXXX'), findsOneWidget);

    // Forgot password flow.
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Send reset link'), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'citizen@nagarsathi.app',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Reset link sent'), findsOneWidget);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    // Sign up wizard.
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);

    // Step 1 validation, then name.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Sita Sharma');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'sita@nagarsathi.app',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 4'), findsOneWidget);

    // Phone is optional.
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('4 of 4'), findsOneWidget);

    final passwordFields = find.byType(TextFormField);
    await tester.enterText(passwordFields.at(0), 'password123');
    await tester.enterText(passwordFields.at(1), 'password123');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text("You're all set"), findsOneWidget);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('New to NagarSathi?'), findsOneWidget);
  });
}
