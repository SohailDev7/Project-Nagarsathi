import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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
  });

  testWidgets('a remembered session opens the citizen home directly', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const NagarSathiApp(startSignedIn: true));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
  });
}
