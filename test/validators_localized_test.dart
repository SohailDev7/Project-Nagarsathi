import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/l10n/app_locale.dart';
import 'package:projectnagarsathi/l10n/app_strings.dart';
import 'package:projectnagarsathi/l10n/language_controller.dart';
import 'package:projectnagarsathi/utils/validators.dart';

void main() {
  group('Validators Localization', () {
    test('returns English error messages when language is English', () {
      LanguageController.instance.value = AppLocale.en;

      expect(
        Validators.identifier(''),
        'Enter your email or phone number',
      );
      expect(
        Validators.email('invalid-email'),
        'Enter a valid email address',
      );
      expect(
        Validators.phone('123'),
        'Enter a valid phone number',
      );
      expect(
        Validators.password('short'),
        'Password must be at least 8 characters',
      );
    });

    test('returns Nepali error messages when language is Nepali', () {
      LanguageController.instance.value = AppLocale.ne;

      expect(
        Validators.identifier(''),
        NepaliStrings.instance.errEmailOrPhone,
      );
      expect(
        Validators.email('invalid-email'),
        NepaliStrings.instance.errInvalidEmail,
      );
      expect(
        Validators.phone('123'),
        NepaliStrings.instance.errInvalidPhone,
      );
      expect(
        Validators.password('short'),
        NepaliStrings.instance.errPasswordLength,
      );
    });

    test('accepts explicit strings override parameter', () {
      const ne = NepaliStrings.instance;
      expect(
        Validators.identifier('', strings: ne),
        ne.errEmailOrPhone,
      );
    });
  });
}
