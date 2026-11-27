import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/screens/delete_profile_screen.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/services/auth_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/widgets/ns_primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends AuthService {
  CitizenDeletionMethod method = CitizenDeletionMethod.password;
  int deletionCalls = 0;
  int smsRequests = 0;
  String? receivedPassword;
  String? receivedCode;
  AuthFailure? failure;
  Completer<CitizenDeletionResult>? pending;
  CitizenDeletionResult result = const CitizenDeletionResult(
    completed: true,
    emailStatus: DeletionEmailStatus.sent,
  );

  @override
  CitizenDeletionMethod get deletionMethod => method;
  @override
  String get deletionPhoneNumber => '+9779800000000';

  @override
  Future<CitizenDeletionSmsChallenge> requestDeletionSmsCode({
    CitizenDeletionSmsChallenge? previous,
  }) async {
    smsRequests++;
    return const CitizenDeletionSmsChallenge(verificationId: 'sms-challenge');
  }

  @override
  Future<CitizenDeletionResult> deleteCitizenProfile({
    String? password,
    CitizenDeletionSmsChallenge? smsChallenge,
    String? smsCode,
  }) async {
    deletionCalls++;
    receivedPassword = password;
    receivedCode = smsCode;
    if (failure != null) throw failure!;
    return pending == null ? result : await pending!.future;
  }
}

Future<void> _openDeletion(
  WidgetTester tester,
  _FakeAuth auth, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
}) async {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: brightness),
      home: HomeScreen(authService: auth),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home-avatar')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('delete-my-profile')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('delete-my-profile')));
  await tester.pumpAndSettle();
  expect(find.byType(DeleteProfileScreen), findsOneWidget);
  expect(auth.deletionCalls, 0);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Nunito');
    for (final weight in [400, 600, 700, 800, 900]) {
      fonts.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await fonts.load();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'citizen avatar exposes deletion and cancellation keeps the profile',
    (tester) async {
      final auth = _FakeAuth();
      await _openDeletion(tester, auth);
      expect(find.text('Confirm your password'), findsOneWidget);
      await _tap(tester, find.text('Keep my profile'));
      expect(find.byType(DeleteProfileScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(auth.deletionCalls, 0);
    },
  );

  testWidgets(
    'deletion requires both a password and explicit permanent-deletion consent',
    (tester) async {
      final auth = _FakeAuth();
      await _openDeletion(tester, auth);
      await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
      expect(
        find.text('Enter your password to confirm deletion.'),
        findsOneWidget,
      );
      expect(auth.deletionCalls, 0);
      await tester.enterText(find.byType(TextFormField), 'correct-password');
      await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
      expect(
        find.text('Confirm that you understand deletion is permanent.'),
        findsOneWidget,
      );
      expect(auth.deletionCalls, 0);
    },
  );

  testWidgets(
    'verification errors keep the screen open and allow a safe retry',
    (tester) async {
      final auth = _FakeAuth()
        ..failure = const AuthFailure('Email or password is incorrect.');
      await _openDeletion(tester, auth);
      await tester.enterText(find.byType(TextFormField), 'wrong-password');
      await _tap(tester, find.byKey(const Key('confirm-profile-deletion')));
      await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.byType(DeleteProfileScreen), findsOneWidget);
      expect(find.text('Profile deleted'), findsNothing);
      auth.failure = null;
      await tester.enterText(find.byType(TextFormField), 'correct-password');
      await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
      expect(auth.receivedPassword, 'correct-password');
      expect(find.text('Profile deleted'), findsOneWidget);
      expect(
        find.text('A confirmation has been sent to your email.'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('deletion-back-to-sign-in')));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(DeleteProfileScreen), findsNothing);
    },
  );

  testWidgets(
    'an in-progress deletion blocks duplicate submissions and back navigation',
    (tester) async {
      final auth = _FakeAuth()..pending = Completer<CitizenDeletionResult>();
      await _openDeletion(tester, auth);
      await tester.enterText(find.byType(TextFormField), 'correct-password');
      await _tap(tester, find.byKey(const Key('confirm-profile-deletion')));
      final submit = find.byKey(const Key('confirm-delete-profile'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      expect(auth.deletionCalls, 1);
      expect(tester.widget<NsPrimaryButton>(submit).isLoading, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(DeleteProfileScreen), findsOneWidget);
      auth.pending!.complete(auth.result);
      await tester.pumpAndSettle();
      expect(find.text('Profile deleted'), findsOneWidget);
    },
  );

  testWidgets('a pending cleanup is clearly presented as a saved request', (
    tester,
  ) async {
    final auth = _FakeAuth()
      ..result = const CitizenDeletionResult(
        completed: false,
        emailStatus: DeletionEmailStatus.pending,
      );
    await _openDeletion(tester, auth);
    await tester.enterText(find.byType(TextFormField), 'correct-password');
    await _tap(tester, find.byKey(const Key('confirm-profile-deletion')));
    await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
    expect(find.text('Deletion requested'), findsOneWidget);
    expect(find.text('Profile deleted'), findsNothing);
    expect(find.textContaining('within 30 days'), findsOneWidget);
  });

  testWidgets('phone accounts must request and enter a valid SMS code', (
    tester,
  ) async {
    final auth = _FakeAuth()..method = CitizenDeletionMethod.sms;
    await _openDeletion(tester, auth);
    expect(find.text('Confirm your password'), findsNothing);
    await _tap(tester, find.byKey(const Key('confirm-profile-deletion')));
    await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
    expect(auth.deletionCalls, 0);
    expect(
      find.text('Request an SMS verification code first.'),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(const Key('send-deletion-sms')));
    expect(auth.smsRequests, 1);
    await tester.enterText(find.byType(TextFormField), '123');
    await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
    expect(auth.deletionCalls, 0);
    await tester.enterText(find.byType(TextFormField), '123456');
    await _tap(tester, find.byKey(const Key('confirm-delete-profile')));
    expect(auth.receivedCode, '123456');
    expect(find.text('Profile deleted'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('deletion-back-to-sign-in')));
  });

  testWidgets('deletion stays scrollable on a small dark screen', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await _openDeletion(
      tester,
      auth,
      size: const Size(320, 568),
      brightness: Brightness.dark,
    );
    await _tap(tester, find.text('Keep my profile'));
    expect(auth.deletionCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable authentication blocks deletion with a clear message',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const DeleteProfileScreen()),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Firebase is not connected. Profile deletion is unavailable.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<NsPrimaryButton>(
              find.byKey(const Key('confirm-delete-profile')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Profile deleted'), findsNothing);
    },
  );
}
