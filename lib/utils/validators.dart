import 'package:flutter/widgets.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_controller.dart';

/// Shared form validators with immediate bilingual localization.
enum IdentifierKind { empty, email, phone, unknown }

abstract final class Validators {
  static final _emailPattern = RegExp(r'^[\w.\-+]+@[\w\-]+(\.[\w\-]+)+$');
  static final _phoneCharacters = RegExp(r'^[+]?[\d\s()\-]+$');
  static final _devanagariDigits = RegExp(r'[०-९]');
  static final _nepaliMobilePattern = RegExp(r'^9[6-8]\d{8}$');
  static final _otpPattern = RegExp(r'^\d{6}$');

  static AppStrings _resolveStrings([AppStrings? strings]) =>
      strings ?? AppStrings.forLocale(LanguageController.instance.value);

  /// Detects whether the shared sign-in field holds an email or a phone.
  static IdentifierKind identifierKind(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return IdentifierKind.empty;
    if (trimmed.contains('@')) return IdentifierKind.email;
    if (_phoneCharacters.hasMatch(trimmed)) return IdentifierKind.phone;
    return IdentifierKind.unknown;
  }

  static String? identifier(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    switch (identifierKind(value)) {
      case IdentifierKind.empty:
        return s.errEmailOrPhone;
      case IdentifierKind.email:
        return email(value, strings: s);
      case IdentifierKind.phone:
        return phone(value, strings: s);
      case IdentifierKind.unknown:
        return s.errInvalidEmailOrPhone;
    }
  }

  static String? name(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return s.errName;
    if (trimmed.length < 2) return s.errNameLength;
    return null;
  }

  static String? email(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return s.errEmail;
    if (!_emailPattern.hasMatch(trimmed)) return s.errInvalidEmail;
    return null;
  }

  static String? phone(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    final digits = (value ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return s.errPhone;
    if (digits.length < 7 || digits.length > 15) {
      return s.errInvalidPhone;
    }
    return null;
  }

  static String? optionalPhone(String? value, {AppStrings? strings}) {
    if ((value ?? '').trim().isEmpty) return null;
    return phone(value, strings: strings);
  }

  /// Converts local, `+977`, `977` and `00977` input to an E.164 number.
  /// Returns null when the number is not a Nepali mobile number.
  static String? normalizeNepaliPhone(String? value) {
    final localized = (value ?? '').replaceAllMapped(
      _devanagariDigits,
      (match) => String.fromCharCode(
        match.group(0)!.codeUnitAt(0) - '०'.codeUnitAt(0) + '0'.codeUnitAt(0),
      ),
    );
    final compact = localized.replaceAll(RegExp(r'[\s()\-]'), '');

    final national = compact.startsWith('+977')
        ? compact.substring(4)
        : compact.startsWith('00977') && compact.length == 15
        ? compact.substring(5)
        : compact.startsWith('977') && compact.length == 13
        ? compact.substring(3)
        : compact;

    if (!_nepaliMobilePattern.hasMatch(national)) return null;
    return '+977$national';
  }

  static String? nepaliPhone(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    if ((value ?? '').trim().isEmpty) return s.errPhone;
    if (normalizeNepaliPhone(value) == null) {
      return s.errNepaliPhone;
    }
    return null;
  }

  static String? otp(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    if (value == null || !_otpPattern.hasMatch(value.trim())) {
      return s.errOtpFormat;
    }
    return null;
  }

  static String? password(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    final password = value ?? '';
    if (password.isEmpty) return s.errRequired;
    if (password.length < 8) return s.errPasswordLength;
    return null;
  }

  static String? loginPassword(String? value, {AppStrings? strings}) {
    final s = _resolveStrings(strings);
    if (value == null || value.isEmpty) return s.errRequired;
    return null;
  }

  static String? Function(String?) confirmPassword(
    TextEditingController password, {
    AppStrings? strings,
  }) {
    final s = _resolveStrings(strings);
    return (String? value) {
      if (value == null || value.isEmpty) return s.errRequired;
      if (value != password.text) return s.errPasswordMatch;
      return null;
    };
  }
}
