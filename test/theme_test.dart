import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/settings_screen.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ThemeController', () {
    test('defaults to following the system when nothing is stored', () async {
      final controller = ThemeController();
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });

    test('persists a selection and restores it', () async {
      final controller = ThemeController();
      await controller.setMode(ThemeMode.light);
      expect(controller.value, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.storageKey), 'light');

      final restored = ThemeController();
      await restored.load();
      expect(restored.value, ThemeMode.light);
    });

    test('loads a previously stored dark mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ThemeController.storageKey: 'dark',
      });

      final controller = ThemeController();
      await controller.load();
      expect(controller.value, ThemeMode.dark);
    });

    test('falls back to the system mode for unknown stored values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ThemeController.storageKey: 'purple',
      });

      final controller = ThemeController(ThemeMode.dark);
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });
  });

  group('theme wiring', () {
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

    testWidgets('system dark brightness uses the dark palette', (tester) async {
      usePhoneSurface(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final controller = ThemeController(ThemeMode.system);
      addTearDown(controller.dispose);

      await tester.pumpWidget(NagarSathiApp(themeController: controller));
      await tester.pumpAndSettle();

      final context = tester.element(find.textContaining('Welcome').first);
      final theme = Theme.of(context);

      expect(theme.brightness, Brightness.dark);
      expect(NsColors.of(context).background, const Color(0xFF072A1C));
      expect(NsColors.of(context).surface, const Color(0xFF0E3B27));
      expect(theme.colorScheme.onPrimary, const Color(0xFF163B2B));
    });

    testWidgets('changing the controller switches the theme immediately', (
      tester,
    ) async {
      usePhoneSurface(tester);

      final controller = ThemeController(ThemeMode.light);
      addTearDown(controller.dispose);

      await tester.pumpWidget(NagarSathiApp(themeController: controller));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.textContaining('Welcome').first))
            .brightness,
        Brightness.light,
      );

      await controller.setMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.textContaining('Welcome').first))
            .brightness,
        Brightness.dark,
      );
    });

    testWidgets('settings screen selects the tapped mode', (tester) async {
      usePhoneSurface(tester);

      final controller = ThemeController(ThemeMode.system);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.byKey(const Key('theme-mode-dark')));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.dark);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
