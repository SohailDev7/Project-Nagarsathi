import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/screens/staff_home_screen.dart';
import 'package:projectnagarsathi/services/session_service.dart';
import 'package:projectnagarsathi/services/staff_auth_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/widgets/ns_remember_me_notification.dart';
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('SessionService', () {
    test('remembers the citizen by default', () async {
      expect(await const SessionService().loadRememberMe(), isTrue);
    });

    test('persists an opt-out across launches', () async {
      await const SessionService().saveRememberMe(false);
      expect(await const SessionService().loadRememberMe(), isFalse);
    });

    test('persists opting back in', () async {
      await const SessionService().saveRememberMe(false);
      await const SessionService().saveRememberMe(true);
      expect(await const SessionService().loadRememberMe(), isTrue);
    });

    test('persists and clears staff session', () async {
      expect(await const SessionService().loadStaffSession(), isNull);

      await const SessionService().saveStaffSession(
        identifier: 'officer@ward4.kmc.gov.np',
        isPhone: false,
      );
      final session = await const SessionService().loadStaffSession();
      expect(session, isNotNull);
      expect(session!.identifier, 'officer@ward4.kmc.gov.np');
      expect(session.isPhone, isFalse);

      await const SessionService().clearStaffSession();
      expect(await const SessionService().loadStaffSession(), isNull);
    });
  });

  testWidgets('a remembered session opens the citizen home directly', (
    tester,
  ) async {
    disableAnimations(tester);

    await tester.pumpWidget(const NagarSathiApp(startSignedIn: true));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
  });

  testWidgets('a remembered staff session opens staff workspace directly', (
    tester,
  ) async {
    disableAnimations(tester);

    await tester.pumpWidget(
      const NagarSathiApp(
        startSignedIn: true,
        initialStaffSession: StaffSession(
          identifier: 'officer@ward4.kmc.gov.np',
          isPhone: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StaffHomeScreen), findsOneWidget);
    expect(find.text('Staff workspace'), findsOneWidget);
  });

  testWidgets('login screen does not contain old remember me checkbox', (
    tester,
  ) async {
    disableAnimations(tester);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Remember me on this device'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('NsRememberMeNotification renders in light mode with actions', (
    tester,
  ) async {
    disableAnimations(tester);
    var remembered = false;
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: NsRememberMeNotification(
            isStaff: false,
            onRemember: () => remembered = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remember me on this device?'), findsOneWidget);
    expect(find.text('NAGARSATHI • SECURITY'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);

    await tester.tap(find.text('Remember me'));
    await tester.pump();
    expect(remembered, isTrue);

    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('NsRememberMeNotification renders in dark mode for staff/admin', (
    tester,
  ) async {
    disableAnimations(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: NsRememberMeNotification(
            isStaff: true,
            onRemember: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remember me on this device?'), findsOneWidget);
    expect(find.text('STAFF & ADMIN • SECURITY'), findsOneWidget);
    expect(
      find.text(
        'Stay signed in on this device so you can quickly manage municipality duties, respond to reports, and access admin tools without signing in each time.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('showRememberMeNotification saves choice when Remember me is chosen', (
    tester,
  ) async {
    disableAnimations(tester);
    const session = SessionService();
    await session.saveRememberMe(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showRememberMeNotification(
                  context: context,
                  isStaff: false,
                  sessionService: session,
                ),
                child: const Text('Trigger'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(NsRememberMeNotification), findsOneWidget);
    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();

    expect(find.byType(NsRememberMeNotification), findsNothing);
    expect(await session.loadRememberMe(), isTrue);
  });

  testWidgets('showRememberMeNotification saves false when Not now is chosen', (
    tester,
  ) async {
    disableAnimations(tester);
    const session = SessionService();
    await session.saveRememberMe(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showRememberMeNotification(
                context: context,
                isStaff: true,
                staffIdentifier: 'staff@kmc.gov.np',
                sessionService: session,
              ),
              child: const Text('Trigger'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.byType(NsRememberMeNotification), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(NsRememberMeNotification), findsNothing);
    expect(await session.loadRememberMe(), isFalse);
    expect(await session.loadStaffSession(), isNull);
  });
}
