import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/app_strings.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/app_lock_screen.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/screens/settings_screen.dart';
import 'package:projectnagarsathi/screens/staff_home_screen.dart';
import 'package:projectnagarsathi/screens/staff_login_screen.dart';
import 'package:projectnagarsathi/services/biometric_service.dart';
import 'package:projectnagarsathi/services/session_service.dart';
import 'package:projectnagarsathi/services/staff_auth_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/theme/theme_controller.dart';
import 'package:projectnagarsathi/widgets/app_lock_gate.dart';
import 'package:projectnagarsathi/widgets/ns_app_lock_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({
    this.deviceSupported = true,
    this.biometrics = const <BiometricType>[],
    this.authResult = true,
    this.authException,
    this.throwOnSupport = false,
  });

  bool deviceSupported;
  List<BiometricType> biometrics;
  bool authResult;
  Object? authException;
  bool throwOnSupport;

  @override
  Future<bool> isDeviceSupported() async {
    if (throwOnSupport) throw StateError('platform unavailable');
    return deviceSupported;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      if (authException != null) return Future<bool>.error(authException!);
      return Future<bool>.value(authResult);
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({
    this.currentAvailability = const BiometricAvailability(
      deviceSupported: true,
      biometrics: <BiometricType>[BiometricType.face, BiometricType.fingerprint],
    ),
    this.outcome = const BiometricOutcome.success(),
  });

  BiometricAvailability currentAvailability;
  BiometricOutcome outcome;
  int availabilityCalls = 0;
  int authenticateCalls = 0;
  String? lastReason;

  @override
  Future<BiometricAvailability> availability() async {
    availabilityCalls++;
    return currentAvailability;
  }

  @override
  Future<BiometricOutcome> authenticate({
    String reason = 'Unlock NagarSathi',
  }) async {
    authenticateCalls++;
    lastReason = reason;
    return outcome;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  void usePhoneSurface(WidgetTester tester) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('BiometricAvailability', () {
    test('formats summaries and action labels for face, fingerprint, and PIN', () {
      const full = BiometricAvailability(
        deviceSupported: true,
        biometrics: <BiometricType>[
          BiometricType.face,
          BiometricType.fingerprint,
        ],
      );
      expect(full.isSupported, isTrue);
      expect(
        full.methodSummary,
        'Face unlock, fingerprint, and screen lock PIN',
      );
      expect(full.actionLabel, 'Unlock with face or fingerprint');

      const pinOnly = BiometricAvailability(
        deviceSupported: true,
        biometrics: <BiometricType>[],
      );
      expect(pinOnly.isSupported, isTrue);
      expect(pinOnly.methodSummary, 'Screen lock PIN');
      expect(pinOnly.actionLabel, 'Unlock with device PIN');

      const faceOnly = BiometricAvailability(
        deviceSupported: false,
        biometrics: <BiometricType>[BiometricType.face],
      );
      expect(faceOnly.isSupported, isTrue);
      expect(faceOnly.methodSummary, 'Face unlock');
      expect(faceOnly.actionLabel, 'Unlock with face');

      const fingerprintOnly = BiometricAvailability(
        deviceSupported: false,
        biometrics: <BiometricType>[BiometricType.fingerprint],
      );
      expect(fingerprintOnly.isSupported, isTrue);
      expect(fingerprintOnly.methodSummary, 'Fingerprint');
      expect(fingerprintOnly.actionLabel, 'Unlock with fingerprint');

      const generic = BiometricAvailability(
        deviceSupported: true,
        biometrics: <BiometricType>[BiometricType.strong],
      );
      expect(generic.hasGenericBiometric, isTrue);
      expect(generic.methodSummary, 'Biometric unlock and screen lock PIN');
      expect(generic.actionLabel, 'Unlock with biometrics');

      expect(BiometricAvailability.unsupported.isSupported, isFalse);
      expect(
        BiometricAvailability.unsupported.methodSummary,
        'No screen lock set up',
      );
    });
  });

  group('BiometricService', () {
    test('reads availability and safely falls back when platform throws', () async {
      final supported = BiometricService(
        authentication: _FakeLocalAuth(
          deviceSupported: true,
          biometrics: const <BiometricType>[BiometricType.fingerprint],
        ),
      );
      final avail = await supported.availability();
      expect(avail.isSupported, isTrue);
      expect(avail.hasFingerprint, isTrue);
      expect(avail.deviceSupported, isTrue);

      final broken = BiometricService(
        authentication: _FakeLocalAuth(throwOnSupport: true),
      );
      final brokenAvail = await broken.availability();
      expect(brokenAvail.isSupported, isFalse);
    });

    test('maps authenticate outcomes and LocalAuthException codes', () async {
      final ok = BiometricService(
        authentication: _FakeLocalAuth(authResult: true),
      );
      expect((await ok.authenticate()).success, isTrue);

      final rejected = BiometricService(
        authentication: _FakeLocalAuth(authResult: false),
      );
      final rejectedOutcome = await rejected.authenticate();
      expect(rejectedOutcome.success, isFalse);
      expect(rejectedOutcome.message, contains('did not verify'));

      final canceled = BiometricService(
        authentication: _FakeLocalAuth(
          authException: const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          ),
        ),
      );
      expect((await canceled.authenticate()).message, contains('cancelled'));

      final noCreds = BiometricService(
        authentication: _FakeLocalAuth(
          authException: const LocalAuthException(
            code: LocalAuthExceptionCode.noCredentialsSet,
          ),
        ),
      );
      expect(
        (await noCreds.authenticate()).message,
        contains('no longer has a screen lock'),
      );

      final locked = BiometricService(
        authentication: _FakeLocalAuth(
          authException: const LocalAuthException(
            code: LocalAuthExceptionCode.biometricLockout,
          ),
        ),
      );
      expect((await locked.authenticate()).message, contains('locked'));
    });
  });

  group('SessionService appLock', () {
    test('defaults to false and persists changes', () async {
      const session = SessionService();
      expect(await session.loadAppLock(), isFalse);

      await session.saveAppLock(true);
      expect(await session.loadAppLock(), isTrue);

      await session.saveAppLock(false);
      expect(await session.loadAppLock(), isFalse);
    });
  });

  group('showAppLockOffer', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required _FakeBiometricService biometrics,
      SessionService session = const SessionService(),
      bool isStaff = false,
      ValueChanged<bool>? onDone,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final enabled = await showAppLockOffer(
                    context: context,
                    isStaff: isStaff,
                    sessionService: session,
                    biometricService: biometrics,
                  );
                  onDone?.call(enabled);
                },
                child: const Text('Offer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('skips when Remember me is false', (tester) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(false);
      final biometrics = _FakeBiometricService();
      bool? result;

      await pumpHost(
        tester,
        biometrics: biometrics,
        session: session,
        onDone: (v) => result = v,
      );
      await tester.tap(find.text('Offer'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Lock NagarSathi with your device?'), findsNothing);
      expect(await session.loadAppLock(), isFalse);
    });

    testWidgets('skips when device has no face, fingerprint, or PIN', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(true);
      final biometrics = _FakeBiometricService(
        currentAvailability: BiometricAvailability.unsupported,
      );
      bool? result;

      await pumpHost(
        tester,
        biometrics: biometrics,
        session: session,
        onDone: (v) => result = v,
      );
      await tester.tap(find.text('Offer'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Lock NagarSathi with your device?'), findsNothing);
    });

    testWidgets('enables App Lock only after biometric verification succeeds', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(true);
      final biometrics = _FakeBiometricService();
      bool? result;

      await pumpHost(
        tester,
        biometrics: biometrics,
        session: session,
        onDone: (v) => result = v,
      );
      await tester.tap(find.text('Offer'));
      await tester.pumpAndSettle();

      expect(find.text('Lock NagarSathi with your device?'), findsOneWidget);
      expect(find.text('Face scan'), findsOneWidget);
      expect(find.text('Fingerprint'), findsOneWidget);
      expect(find.text('Screen lock PIN'), findsOneWidget);

      await tester.tap(find.text('Turn on app lock'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(biometrics.authenticateCalls, 1);
      expect(await session.loadAppLock(), isTrue);
    });

    testWidgets('keeps App Lock off if verification fails or user declines', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(true);
      final biometrics = _FakeBiometricService(
        outcome: const BiometricOutcome.failure('Unlock cancelled.'),
      );
      bool? result;

      await pumpHost(
        tester,
        biometrics: biometrics,
        session: session,
        onDone: (v) => result = v,
      );

      // Decline first
      await tester.tap(find.text('Offer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(biometrics.authenticateCalls, 0);
      expect(await session.loadAppLock(), isFalse);

      // Accept sheet, fail biometric check
      await tester.tap(find.text('Offer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on app lock'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(biometrics.authenticateCalls, 1);
      expect(await session.loadAppLock(), isFalse);
    });
  });

  group('AppLockScreen', () {
    testWidgets('unlocks to target screen when verification passes', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final biometrics = _FakeBiometricService();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppLockScreen(
            autoPrompt: false,
            biometricService: biometrics,
            target: (_) => const Scaffold(body: Text('Unlocked Home')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NagarSathi is locked'), findsOneWidget);
      expect(find.text('FACE UNLOCK'), findsOneWidget);
      expect(find.text('FINGERPRINT'), findsOneWidget);
      expect(find.text('SCREEN LOCK PIN'), findsOneWidget);

      await tester.tap(find.text('Unlock with face or fingerprint'));
      await tester.pumpAndSettle();

      expect(find.text('Unlocked Home'), findsOneWidget);
    });

    testWidgets('shows failure message and stays locked when verification fails', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final biometrics = _FakeBiometricService(
        outcome: const BiometricOutcome.failure('Not recognized.'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppLockScreen(
            autoPrompt: false,
            biometricService: biometrics,
            target: (_) => const Scaffold(body: Text('Unlocked Home')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock with face or fingerprint'));
      await tester.pumpAndSettle();

      expect(find.text('Not recognized.'), findsOneWidget);
      expect(find.text('Unlocked Home'), findsNothing);
    });

    testWidgets('resumeMode pops on unlock and blocks hardware back button', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final biometrics = _FakeBiometricService();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AppLockScreen(
                        resumeMode: true,
                        autoPrompt: false,
                        biometricService: biometrics,
                        target: (_) => const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                child: const Text('Lock'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      // Hardware/gesture back must NOT bypass the lock screen.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.tap(find.text('Unlock with face or fingerprint'));
      await tester.pumpAndSettle();
      expect(find.text('Lock'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
    });

    testWidgets('re-checks availability on resume when previously unsupported', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final biometrics = _FakeBiometricService(
        currentAvailability: BiometricAvailability.unsupported,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppLockScreen(
            autoPrompt: false,
            biometricService: biometrics,
            target: (_) => const Scaffold(body: Text('Unlocked Home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in with password'), findsOneWidget);

      // Simulate user enrolling a screen lock PIN in phone settings and
      // returning to the app.
      biometrics.currentAvailability = const BiometricAvailability(
        deviceSupported: true,
        biometrics: <BiometricType>[],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Unlock with device PIN'), findsOneWidget);
    });

    testWidgets('Not you? Sign out clears session flags for citizen and staff', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(true);
      await session.saveAppLock(true);
      await session.saveStaffSession(
        identifier: 'staff@kmc.gov.np',
        isPhone: false,
      );

      final biometrics = _FakeBiometricService();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppLockScreen(
            isStaff: true,
            autoPrompt: false,
            biometricService: biometrics,
            sessionService: session,
            target: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not you? Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out instead?'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(await session.loadRememberMe(), isFalse);
      expect(await session.loadAppLock(), isFalse);
      expect(await session.loadStaffSession(), isNull);
      expect(find.byType(StaffLoginScreen), findsOneWidget);
    });
  });

  group('AppLockGate', () {
    testWidgets('re-locks after background interval when Remember me and App Lock are on', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(true);
      await session.saveAppLock(true);
      final biometrics = _FakeBiometricService();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppLockGate(
            relockAfter: Duration.zero,
            sessionService: session,
            biometricService: biometrics,
            child: const Scaffold(body: Text('Active Workspace')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Active Workspace'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Let autoPrompt timer (320ms) and verification run.
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(biometrics.authenticateCalls, 1);
      expect(find.text('Active Workspace'), findsOneWidget);
    });

    testWidgets('does not lock when Remember me is off', (tester) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(false);
      await session.saveAppLock(true);
      final biometrics = _FakeBiometricService();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppLockGate(
            relockAfter: Duration.zero,
            sessionService: session,
            biometricService: biometrics,
            child: const Scaffold(body: Text('Active Workspace')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(biometrics.authenticateCalls, 0);
      expect(find.byType(AppLockScreen), findsNothing);
    });
  });

  group('SettingsScreen security & NagarSathiApp cold start', () {
    testWidgets('SettingsScreen toggles App Lock after biometric verification', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(true);
      await session.saveAppLock(false);
      final biometrics = _FakeBiometricService();
      final controller = ThemeController(ThemeMode.light);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            controller: controller,
            sessionService: session,
            biometricService: biometrics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appLockTitle = find.text('App lock');
      await tester.scrollUntilVisible(
        appLockTitle,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('OFF'), findsOneWidget);
      expect(
        find.text('Available: Face unlock, fingerprint, and screen lock PIN'),
        findsOneWidget,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(biometrics.authenticateCalls, 1);
      expect(await session.loadAppLock(), isTrue);
      expect(find.text('ON'), findsOneWidget);

      // Failed biometric verification keeps App Lock ON.
      biometrics.outcome = const BiometricOutcome.failure('Cancelled');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(await session.loadAppLock(), isTrue);
      expect(find.text('ON'), findsOneWidget);

      // Passing biometric verification turns App Lock OFF.
      biometrics.outcome = const BiometricOutcome.success();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(await session.loadAppLock(), isFalse);
      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('SettingsScreen disables App Lock switch when Remember me is off', (
      tester,
    ) async {
      usePhoneSurface(tester);
      const session = SessionService();
      await session.saveRememberMe(false);
      final biometrics = _FakeBiometricService();
      final controller = ThemeController(ThemeMode.light);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            controller: controller,
            sessionService: session,
            biometricService: biometrics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('App lock'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);
      expect(
        find.text(
          'Turning this on needs Remember me. Sign in again and choose '
          'Remember me, then come back here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('NagarSathiApp cold start shows AppLockScreen when appLockEnabled is true', (
      tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        const NagarSathiApp(
          startSignedIn: true,
          appLockEnabled: true,
          initialStaffSession: StaffSession(
            identifier: 'officer@ward4.kmc.gov.np',
            isPhone: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppLockScreen), findsOneWidget);
      expect(find.text('Staff workspace locked'), findsOneWidget);
      expect(find.byType(StaffHomeScreen), findsNothing);
    });

    testWidgets('StaffHomeScreen opens SettingsScreen from Settings button', (
      tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(
        AppStringsScope(
          strings: AppStrings.forLocale(AppLocale.en),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const StaffHomeScreen(staffIdentifier: 'staff@kmc.gov.np'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final settingsButton = find.byKey(const Key('staff-open-settings'));
      expect(settingsButton, findsOneWidget);
      await tester.ensureVisible(settingsButton);
      await tester.pumpAndSettle();
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('App lock'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('App lock'), findsOneWidget);
    });
  });

  group('Citizen non-app-lock regression check', () {
    testWidgets('NagarSathiApp opens LoginScreen when not signed in', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const NagarSathiApp());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
