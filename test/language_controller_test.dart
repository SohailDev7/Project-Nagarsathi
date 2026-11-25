import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/language_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LanguageController', () {
    test('defaults to English on fresh launch', () {
      final controller = LanguageController();
      expect(controller.value, AppLocale.en);
      expect(controller.value.isEnglish, isTrue);
      expect(controller.value.isNepali, isFalse);
    });

    test('toggles cleanly between English and Nepali', () async {
      final controller = LanguageController(AppLocale.en);
      expect(controller.value, AppLocale.en);

      await controller.toggle();
      expect(controller.value, AppLocale.ne);
      expect(controller.value.isNepali, isTrue);

      await controller.toggle();
      expect(controller.value, AppLocale.en);
      expect(controller.value.isEnglish, isTrue);
    });

    test('persists selection to SharedPreferences', () async {
      final controller = LanguageController();
      await controller.setLocale(AppLocale.ne);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LanguageController.storageKey), 'ne');

      // Create new controller and load
      final restored = LanguageController();
      await restored.load();
      expect(restored.value, AppLocale.ne);
    });
  });

  group('AppLocale formatting', () {
    test('formatDigits converts numbers to Devanagari in Nepali mode', () {
      expect(AppLocale.ne.formatDigits('Ward 3'), 'Ward ३');
      expect(AppLocale.ne.formatDigits(123456), '१२३४५६');
      expect(AppLocale.ne.formatDigits('2026-11-23'), '२०२६-११-२३');
    });

    test('formatDigits preserves Arabic numerals in English mode', () {
      expect(AppLocale.en.formatDigits('Ward 3'), 'Ward 3');
      expect(AppLocale.en.formatDigits(123456), '123456');
    });

    test('toggle target labels reflect user goal', () {
      expect(AppLocale.en.toggleTargetLabel, 'ने');
      expect(AppLocale.ne.toggleTargetLabel, 'EN');
    });
  });
}
