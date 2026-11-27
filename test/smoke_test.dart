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
      find.text(
        'Firebase is not connected. Sign-in is unavailable.',
      ),
      findsAtLeastNWidgets(1),
    );

    // Sign-up wizard.
    await tester.ensureVisible(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    // Details are validated together, so the first tap reports both errors.
    await tester.ensureVisible(find.text('Continue'));
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
    await tester.ensureVisible(find.text('Continue'));
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

    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
