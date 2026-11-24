import 'package:flutter/widgets.dart';

/// Supported application locales.
enum AppLocale {
  en('en', 'English', 'English', 'ने', Locale('en', 'US')),
  ne('ne', 'नेपाली', 'नेपाली भाषा', 'EN', Locale('ne', 'NP'));

  const AppLocale(
    this.code,
    this.label,
    this.nativeSubtitle,
    this.toggleTargetLabel,
    this.locale,
  );

  /// ISO 639-1 language code ('en' or 'ne').
  final String code;

  /// Display name in its native script.
  final String label;

  /// Descriptive subtitle for settings.
  final String nativeSubtitle;

  /// The label shown on the 1-tap header toggle indicating what it will switch to.
  /// When current is English, shows 'ने'; when current is Nepali, shows 'EN'.
  final String toggleTargetLabel;

  /// Flutter [Locale] representation.
  final Locale locale;

  bool get isNepali => this == AppLocale.ne;
  bool get isEnglish => this == AppLocale.en;

  /// Returns the alternate locale for 1-tap toggling.
  AppLocale get toggled => isNepali ? AppLocale.en : AppLocale.ne;

  /// Converts standard Arabic digits (0-9) in [input] to Devanagari numerals (०-९)
  /// when this locale is Nepali. Returns [input] unchanged if this locale is English.
  String formatDigits(Object input) {
    final str = input.toString();
    if (!isNepali) return str;
    const arabic = '0123456789';
    const devanagari = '०१२३४५६७८९';
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      final index = arabic.indexOf(char);
      if (index != -1) {
        buffer.write(devanagari[index]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static AppLocale fromCode(String? code) {
    if (code == 'ne') return AppLocale.ne;
    return AppLocale.en;
  }
}
