import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/app_strings.dart';
import 'package:projectnagarsathi/l10n/language_controller.dart';
import 'package:projectnagarsathi/main.dart';
import 'package:projectnagarsathi/screens/login_screen.dart';
import 'package:projectnagarsathi/screens/settings_screen.dart';
import 'package:projectnagarsathi/theme/theme_controller.dart';
import 'package:projectnagarsathi/widgets/ns_language_toggle.dart';
import 'package:projectnagarsathi/widgets/ns_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material localizations exist after switching to Nepali', (
    tester,
  ) async {
    final controller = LanguageController(AppLocale.en);
    await tester.pumpWidget(NagarSathiApp(languageController: controller));
    await tester.pumpAndSettle();

    controller.value = AppLocale.ne;
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(LoginScreen));
    expect(
      MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      isNotEmpty,
    );
    expect(find.text('पुन: स्वागत छ'), findsOneWidget);
    expect(find.text('इमेल वा फोन नम्बर'), findsOneWidget);
    expect(find.text('अगाडि बढ्नुहोस्'), findsOneWidget);
    expect(find.text('गुगलबाट जारी राख्नुहोस्'), findsOneWidget);
    expect(find.text('नगरसाथीमा नयाँ हुनुहुन्छ?'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Email or phone number'), findsNothing);
  });

  Widget wrapWithScope({
    required Widget child,
    required LanguageController languageController,
    ThemeController? themeController,
  }) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: languageController,
      builder: (context, locale, _) {
        final strings = AppStrings.forLocale(locale);
        return AppStringsScope(
          strings: strings,
          child: MaterialApp(home: child),
        );
      },
    );
  }

  group('NsLanguageToggle Widget', () {
    testWidgets('renders toggle and switches language on tap', (tester) async {
      final controller = LanguageController(AppLocale.en);

      await tester.pumpWidget(
        wrapWithScope(
          child: Scaffold(
            appBar: AppBar(actions: [NsLanguageToggle(controller: controller)]),
          ),
          languageController: controller,
        ),
      );

      expect(find.byType(NsLanguageToggle), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('ने'), findsNothing);
      expect(find.text('EN'), findsNothing);
      expect(controller.value, AppLocale.en);

      // Tap toggle to switch to Nepali
      await tester.tap(find.byType(NsLanguageToggle));
      await tester.pumpAndSettle();

      expect(controller.value, AppLocale.ne);
      expect(find.text('नेपाली'), findsOneWidget);

      // Tap toggle again to switch back to English
      await tester.tap(find.byType(NsLanguageToggle));
      await tester.pumpAndSettle();

      expect(controller.value, AppLocale.en);
      expect(find.text('English'), findsOneWidget);
    });
  });

  group('NsSettingsSheet Quick Settings', () {
    testWidgets('switches theme and language from the quick sheet', (
      tester,
    ) async {
      final themeController = ThemeController();
      final languageController = LanguageController(AppLocale.en);

      await tester.pumpWidget(
        wrapWithScope(
          child: Scaffold(
            body: NsSettingsSheet(
              themeController: themeController,
              languageController: languageController,
            ),
          ),
          languageController: languageController,
        ),
      );

      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.byKey(const Key('quick-theme-dark')), findsOneWidget);
      expect(find.byKey(const Key('quick-language-ne')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick-theme-dark')));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.dark);

      await tester.tap(find.byKey(const Key('quick-language-ne')));
      await tester.pumpAndSettle();

      expect(languageController.value, AppLocale.ne);
      // The sheet immediately re-renders in Nepali.
      expect(find.text('भाषा'), findsOneWidget);
    });
  });

  group('SettingsScreen Language Section', () {
    testWidgets(
      'renders Language section and updates immediately on selection',
      (tester) async {
        final langController = LanguageController(AppLocale.en);
        final themeController = ThemeController();

        await tester.pumpWidget(
          wrapWithScope(
            child: SettingsScreen(
              controller: themeController,
              languageController: langController,
            ),
            languageController: langController,
          ),
        );

        // Initial state is English
        expect(find.text('Language'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('नेपाली'), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);

        // Select Nepali
        await tester.tap(find.byKey(const Key('language-mode-ne')));
        await tester.pumpAndSettle();

        expect(langController.value, AppLocale.ne);

        // Settings screen should immediately reflect Nepali strings
        expect(find.text('भाषा'), findsOneWidget);
        expect(find.text('थिम'), findsOneWidget);
        expect(find.text('नेपाली भाषा · Nepali'), findsOneWidget);

        // Select English back
        await tester.tap(find.byKey(const Key('language-mode-en')));
        await tester.pumpAndSettle();

        expect(langController.value, AppLocale.en);
        expect(find.text('Language'), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);
      },
    );
  });
}
