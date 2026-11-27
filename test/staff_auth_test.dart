import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/language_controller.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/screens/staff_home_screen.dart';
import 'package:projectnagarsathi/screens/staff_login_screen.dart';
import 'package:projectnagarsathi/services/staff_auth_service.dart';
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
  test('super-admin allowlist accepts only normalized configured emails', () {
    expect(StaffAuthService.isSuperAdminEmail('admin@nagarsathi.app'), isTrue);
    expect(
      StaffAuthService.isSuperAdminEmail(' SohailK2064@Outlook.com '),
      isTrue,
    );
    expect(
      StaffAuthService.isSuperAdminEmail('sohail@nagarsathi.app'),
      isFalse,
    );
    // This address was turned into a ward officer, so it must not be an admin.
    expect(
      StaffAuthService.isSuperAdminEmail(' FreeFuzxcoj2@gmail.com '),
      isFalse,
    );
    expect(StaffAuthService.isSuperAdminEmail('someone@example.com'), isFalse);
    expect(StaffAuthService.isSuperAdminEmail(null), isFalse);
  });

  testWidgets('staff login labels update when switching to Nepali', (
    tester,
  ) async {
    final languageController = LanguageController(AppLocale.en);
    await tester.pumpWidget(
      NagarSathiApp(languageController: languageController),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Staff portal'));
    await tester.tap(find.text('Staff portal'));
    await tester.pumpAndSettle();

    expect(find.text('Email or phone number'), findsOneWidget);
    expect(find.text('Access is issued by your municipality.'), findsOneWidget);

    languageController.value = AppLocale.ne;
    await tester.pumpAndSettle();

    expect(find.text('इमेल वा फोन नम्बर'), findsOneWidget);
    expect(find.text('पहुँच तपाईंको नगरपालिकाले प्रदान गर्छ।'), findsOneWidget);
    expect(find.text('Email or phone number'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text('Email or phone number'), findsOneWidget);
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
    expect(find.text('Enter your email or phone number'), findsOneWidget);
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
    expect(find.text('Enter a valid email or phone number'), findsOneWidget);
    expect(find.byType(StaffLoginScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('staff sign-in is blocked when Firebase is unavailable', (
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(
      find.text('Firebase is not connected. Staff sign-in is unavailable.'),
      findsOneWidget,
    );
    expect(find.byType(StaffLoginScreen), findsOneWidget);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
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
    await tester.enterText(find.byType(TextFormField).first, '919841234567');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid Nepali mobile number'), findsOneWidget);
    expect(find.text('6-digit code'), findsNothing);
    expect(find.byType(StaffHomeScreen), findsNothing);
  });

  testWidgets('staff phone OTP is blocked when Firebase is unavailable', (
    tester,
  ) async {
    await _openStaffPortal(tester);
    await tester.enterText(find.byType(TextFormField).first, '9841234567');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Firebase is not connected. Phone sign-in is unavailable.'),
      findsOneWidget,
    );
    expect(find.text('6-digit code'), findsNothing);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('citizen sign-in is blocked when Firebase is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(const NagarSathiApp());
    await tester.pumpAndSettle();
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
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(StaffHomeScreen), findsNothing);
    expect(find.byType(StaffLoginScreen), findsNothing);
  });
}
