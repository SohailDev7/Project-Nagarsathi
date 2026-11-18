import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

    for (final tab in ['Reports', 'Map', 'Profile']) {
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
    expect(find.text('Sign out'), findsOneWidget);
  });
}
