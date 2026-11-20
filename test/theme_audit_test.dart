import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/models/app_update.dart';
import 'package:projectnagarsathi/models/citizen_location.dart';
import 'package:projectnagarsathi/screens/forgot_password_screen.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/screens/sign_up_screen.dart';
import 'package:projectnagarsathi/screens/staff_home_screen.dart';
import 'package:projectnagarsathi/screens/staff_login_screen.dart';
import 'package:projectnagarsathi/services/location_service.dart';
import 'package:projectnagarsathi/services/update_service.dart';
import 'package:projectnagarsathi/widgets/update_dialog.dart';

import 'support/contrast_audit.dart';

const _ward16 = CitizenLocation(
  latitude: 27.6896,
  longitude: 85.3427,
  municipality: 'Kathmandu Metropolitan City',
  ward: 16,
);

class _FixedLocationService extends LocationService {
  const _FixedLocationService();

  @override
  Future<CitizenLocation?> detect() async => _ward16;
}

const _releaseUrl = 'https://github.com/SohailDev7/Project-Nagarsathi/releases';

const _normalUpdate = AppUpdate(
  version: AppVersion(major: 1, minor: 1, patch: 0, build: 3),
  tag: 'v1.1.0',
  notes:
      'Brand new step-by-step sign up\n'
      'Faster, safer update downloads\n'
      'Fixed the keyboard covering the login button',
  apkUrl: 'https://example.com/app-release.apk',
  apkSize: 51337335,
  isPriority: false,
  releaseUrl: _releaseUrl,
);

const _forcedUpdate = AppUpdate(
  version: AppVersion(major: 2, minor: 0, patch: 0),
  tag: 'v2.0.0-priority',
  notes:
      'Ward boundaries are now drawn on the report map\n'
      'Staff dashboards refresh in the background',
  apkUrl: 'https://example.com/app-release.apk',
  apkSize: 48234496,
  isPriority: true,
  releaseUrl: _releaseUrl,
);

Widget _homeScreen() {
  return const HomeScreen(locationService: _FixedLocationService());
}

Widget _updateHost(AppUpdate update) {
  final service = UpdateService();
  addTearDown(service.dispose);
  return Scaffold(
    // Mirrors the dimmed page behind the real update route.
    backgroundColor: const Color(0xFF2F3A34),
    body: UpdateDialog(update: update, service: service),
  );
}

/// Registers the audit for [screen] in both light and dark mode.
void _auditBothModes(
  String screen,
  Widget Function() home, {
  Future<void> Function(WidgetTester tester)? interact,
  bool settleAfterInteract = true,
  String? note,
}) {
  for (final brightness in const <Brightness>[
    Brightness.light,
    Brightness.dark,
  ]) {
    testWidgets('$screen [${brightness.name}]', (tester) async {
      await auditScreen(
        tester,
        screen: screen,
        brightness: brightness,
        home: home(),
        interact: interact,
        settleAfterInteract: settleAfterInteract,
        note: note,
      );
    });
  }
}

Future<void> _typeLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first,
    'citizen@nagarsathi.app',
  );
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'password123');
  await tester.pumpAndSettle();
}

Future<void> _signUpWithErrors(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _fillSignUpDetails(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Sita Sharma');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'sita@nagarsathi.app',
  );
  await tester.enterText(find.byType(TextFormField).at(2), '+977 9812345678');
  await tester.pumpAndSettle();
}

Future<void> _reachPasswordStep(WidgetTester tester) async {
  await _fillSignUpDetails(tester);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('2 of 3'), findsOneWidget);

  await tester.enterText(find.byType(TextFormField).at(0), 'password123');
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await tester.pumpAndSettle();
}

Future<void> _sendResetLink(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first,
    'citizen@nagarsathi.app',
  );
  await tester.tap(find.text('Send reset link'));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  expect(find.text('Reset link sent'), findsOneWidget);
}

Future<void> _openWardDialog(WidgetTester tester) async {
  await tester.tap(find.text('Set your location'));
  await tester.pumpAndSettle();
  expect(find.text('Are you from'), findsOneWidget);
}

Future<void> _openAccountSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home-avatar')));
  await tester.pumpAndSettle();
  expect(find.text('NagarSathi citizen'), findsOneWidget);
}

Future<void> _openComingSoon(WidgetTester tester) async {
  await tester.tap(find.text('Reports'));
  await tester.pump(const Duration(milliseconds: 120));
  expect(find.text('Feature coming soon.'), findsOneWidget);
}

Future<void> _openMapComingSoon(WidgetTester tester) async {
  await tester.tap(find.text('Map'));
  await tester.pump(const Duration(milliseconds: 120));
  expect(find.text('Feature coming soon.'), findsOneWidget);
}

Future<void> _openProfileComingSoon(WidgetTester tester) async {
  await tester.tap(find.text('Profile'));
  await tester.pump(const Duration(milliseconds: 120));
  expect(find.text('Feature coming soon.'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    themeAuditResults.clear();
    await loadAuditFonts();
  });
  tearDownAll(writeThemeAuditReport);

  group('LoginScreen', () {
    _auditBothModes('LoginScreen', () => const LoginScreen());
    _auditBothModes(
      'LoginScreen (typed)',
      () => const LoginScreen(),
      interact: _typeLogin,
      note: 'Identifier and password filled, so input text is audited too.',
    );
  });

  group('SignUpScreen', () {
    _auditBothModes(
      'SignUpScreen step 1 of 3',
      () => const SignUpScreen(),
      note:
          'Step 3 (email OTP) is unreachable offline: Firebase is not '
          'configured. The step-2 branch in _buildStep is also guarded by '
          '_step == 0, so it can never render.',
    );
    _auditBothModes(
      'SignUpScreen step 1 of 3 (details filled)',
      () => const SignUpScreen(),
      interact: _fillSignUpDetails,
    );
    _auditBothModes(
      'SignUpScreen step 1 of 3 (errors)',
      () => const SignUpScreen(),
      interact: _signUpWithErrors,
      note: 'Validation errors and error borders are visible.',
    );
    _auditBothModes(
      'SignUpScreen step 2 of 3',
      () => const SignUpScreen(),
      interact: _reachPasswordStep,
      note: 'Password strength label and terms row are visible.',
    );
  });

  group('ForgotPasswordScreen', () {
    _auditBothModes('ForgotPasswordScreen', () => const ForgotPasswordScreen());
    _auditBothModes(
      'ForgotPasswordScreen (sent)',
      () => const ForgotPasswordScreen(),
      interact: _sendResetLink,
    );
  });

  group('StaffLoginScreen', () {
    _auditBothModes('StaffLoginScreen', () => const StaffLoginScreen());
  });

  group('HomeScreen', () {
    _auditBothModes('HomeScreen home tab', _homeScreen);
    _auditBothModes(
      'HomeScreen ward dialog',
      _homeScreen,
      interact: _openWardDialog,
      note: 'Ward confirmation dialog over the dimmed home page.',
    );
    _auditBothModes(
      'HomeScreen account sheet',
      _homeScreen,
      interact: _openAccountSheet,
      note: 'Citizen account bottom sheet over the dimmed home page.',
    );
    _auditBothModes(
      'HomeScreen Reports tab',
      _homeScreen,
      interact: _openComingSoon,
      settleAfterInteract: false,
      note: 'Only the Home tab exists; Reports/Map/Profile show snackbars.',
    );
    _auditBothModes(
      'HomeScreen Map tab',
      _homeScreen,
      interact: _openMapComingSoon,
      settleAfterInteract: false,
    );
    _auditBothModes(
      'HomeScreen Profile tab',
      _homeScreen,
      interact: _openProfileComingSoon,
      settleAfterInteract: false,
    );
  });

  group('StaffHomeScreen', () {
    _auditBothModes(
      'StaffHomeScreen',
      () => const StaffHomeScreen(staffIdentifier: 'staff@kmc.gov.np'),
    );
  });

  group('UpdateDialog', () {
    _auditBothModes(
      'UpdateDialog normal',
      () => _updateHost(_normalUpdate),
      note: 'Optional update: hold-outside hint is visible.',
    );
    _auditBothModes(
      'UpdateDialog forced',
      () => _updateHost(_forcedUpdate),
      note: 'Priority update: no hold-to-cancel affordance.',
    );
  });
}
