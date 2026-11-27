import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/screens/citizen_profile_screen.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only the home tab is available for now', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Around you'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);

    for (final tab in ['Reports', 'Map']) {
      await tester.tap(find.text(tab));
      await tester.pump();
      expect(find.text('Feature coming soon.'), findsOneWidget);

      // Home stays put behind the message.
      expect(find.text('Around you'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the avatar opens the citizen account sheet', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.byKey(const Key('home-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('NagarSathi citizen'), findsOneWidget);
    expect(find.text('CITIZEN'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Dark mode'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete my profile'), findsOneWidget);
  });

  testWidgets('the Profile tab opens the citizen profile screen', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(CitizenProfileScreen), findsOneWidget);
    expect(find.text('NagarSathi citizen'), findsWidgets);
    expect(find.text('Edit profile'), findsOneWidget);

    // The account actions stay reachable from the profile's menu.
    await tester.tap(find.byKey(const Key('profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Dark mode'), findsNothing);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theme-mode-dark')), findsOneWidget);
  });
}
