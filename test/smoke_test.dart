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

    // Identifier field detects phone numbers and email addresses live.
    await tester.enterText(find.byType(TextFormField).at(0), '9801234567');
    await tester.pumpAndSettle();
    expect(find.text('Phone'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'citizen@nagarsathi.app',
    );
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Firebase is not connected in unit widget tests, so sign-in reports error.
    expect(
      find.text('Firebase is not connected. Sign-in is unavailable.'),
      findsAtLeastNWidgets(1),
    );

    // Sign-up wizard.
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    // Email and both passwords are validated together.
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('This field is required'), findsNWidgets(2));

    final signUpFields = find.byType(TextFormField);
    expect(signUpFields, findsNWidgets(3));
    await tester.enterText(signUpFields.at(0), 'sita@nagarsathi.app');
    await tester.enterText(signUpFields.at(1), 'password123');
    await tester.enterText(signUpFields.at(2), 'password123');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Firebase is not connected, so the OTP request reports an error instead
    // of advancing to step 2.
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      find.text('Firebase is not connected. Account creation is unavailable.'),
      findsAtLeastNWidgets(1),
    );
  });
}
