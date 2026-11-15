import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/main.dart';

void main() {
  testWidgets('auth flow renders and navigates', (tester) async {
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

    // Sign up screen.
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sita Sharma');
    await tester.enterText(fields.at(1), 'sita@nagarsathi.app');
    await tester.enterText(fields.at(2), '9812345678');
    await tester.enterText(fields.at(3), 'password123');
    await tester.enterText(fields.at(4), 'password123');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(AnimatedContainer));
    await tester.tap(find.byType(AnimatedContainer));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text("You're all set"), findsOneWidget);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('New to NagarSathi?'), findsOneWidget);
  });
}
