import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/screens/staff_home_screen.dart';
import 'package:projectnagarsathi/screens/staff_login_screen.dart';
import 'package:projectnagarsathi/utils/validators.dart';

Future<void> _openStaffPortal(WidgetTester tester) async {
  await tester.pumpWidget(const NagarSathiApp());
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Staff portal'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Staff portal'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'staff portal entry stays visible and returns to citizen sign-in',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NagarSathiApp());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'citizen@nagarsathi.app',
      );
      await tester.pumpAndSettle();

      // The staff entry lives in the bottom section.
      final staffPortal = find.text('Staff portal');
      expect(staffPortal, findsOneWidget);
      await tester.ensureVisible(staffPortal);
      await tester.pumpAndSettle();
      await tester.tap(staffPortal);
      await tester.pumpAndSettle();
      expect(find.byType(StaffLoginScreen), findsOneWidget);
      expect(find.text('Staff sign in'), findsOneWidget);
      expect(find.text('Work email address'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Sign up'), findsNothing);

      await tester.ensureVisible(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'citizen@nagarsathi.app',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('staff sign-in rejects empty and invalid credentials', (
    tester,
  ) async {
    await _openStaffPortal(tester);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(
      tester
          .state<FormFieldState<String>>(find.byType(TextFormField).at(1))
          .errorText,
      'Enter your password',
    );
    expect(find.byType(StaffHomeScreen), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'staff-password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.byType(StaffLoginScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('staff sign-in and sign-out keep the workspace separate', (
    tester,
  ) async {
    await _openStaffPortal(tester);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ward.staff@nagarsathi.gov.np',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'staff-password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(StaffHomeScreen), findsOneWidget);
    expect(find.text('Staff workspace'), findsOneWidget);
    expect(find.text('ward.staff@nagarsathi.gov.np'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(StaffHomeScreen))).canPop(),
      isFalse,
    );

    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(StaffLoginScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);

    await tester.ensureVisible(find.text('Back to citizen sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to citizen sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StaffLoginScreen), findsNothing);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('back during staff sign-in cancels opening the workspace', (
    tester,
  ) async {
    await _openStaffPortal(tester);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ward.staff@nagarsathi.gov.np',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'staff-password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 800));

    Navigator.of(tester.element(find.byType(StaffLoginScreen))).pop();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Nepali phone validation normalizes local and country formats', () {
    expect(Validators.normalizeNepaliPhone('9841234567'), '+9779841234567');
    expect(
      Validators.normalizeNepaliPhone('+977 984-1234567'),
      '+9779841234567',
    );
    expect(Validators.normalizeNepaliPhone('९८४१२३४५६७'), '+9779841234567');
    expect(Validators.nepaliPhone('1234567890'), isNotNull);
    expect(Validators.nepaliPhone('+919841234567'), isNotNull);
    expect(Validators.otp('12345'), isNotNull);
    expect(Validators.otp('123456'), isNull);
  });

  testWidgets('staff phone OTP rejects numbers outside Nepal', (tester) async {
    await _openStaffPortal(tester);
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '919841234567');
    await tester.ensureVisible(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid Nepali mobile number'), findsOneWidget);
    expect(find.text('6-digit code'), findsNothing);
    expect(find.byType(StaffHomeScreen), findsNothing);
  });

  testWidgets('staff phone OTP signs in a registered Nepali number', (
    tester,
  ) async {
    await _openStaffPortal(tester);
    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '9841234567');
    await tester.ensureVisible(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('6-digit code'), findsOneWidget);
    expect(find.text('Demo code: 123456'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.ensureVisible(find.text('Verify & sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify & sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(StaffHomeScreen), findsOneWidget);
    expect(find.text('+9779841234567'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('citizen sign-in continues to open the citizen home', (
    tester,
  ) async {
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'citizen@nagarsathi.app',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'citizen-password',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(StaffLoginScreen), findsNothing);
  });
}
