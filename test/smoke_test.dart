import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';

void main() {
  testWidgets('auth flow renders and navigates', (tester) async {
    // Honour reduced motion so looping decoration never blocks pumpAndSettle.
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome'), findsOneWidget);

    // One field detects phone numbers and email addresses.
    await tester.enterText(find.byType(TextFormField).first, '9801234567');
    await tester.pumpAndSettle();
    expect(find.text('PHONE'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'citizen@nagarsathi.app',
    );
    await tester.pumpAndSettle();
    expect(find.text('EMAIL'), findsOneWidget);

    // Forgot password flow.
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Send reset link'), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email or phone number'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'citizen@nagarsathi.app',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Reset link sent'), findsOneWidget);

    await tester.ensureVisible(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome'), findsOneWidget);

    // Sign-up wizard.
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    // Details are validated together, so the first tap reports both errors.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Sita Sharma');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'sita@nagarsathi.app',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);

    final passwordFields = find.byType(TextFormField);
    expect(passwordFields, findsNWidgets(2));
    await tester.enterText(passwordFields.at(0), 'password123');
    await tester.enterText(passwordFields.at(1), 'password123');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // The wizard now has a third, email-OTP step. Requesting that code needs
    // Firebase, which widget tests do not initialise, so the journey stops
    // here instead of reaching the home screen.
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
