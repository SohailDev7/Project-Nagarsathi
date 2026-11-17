import 'package:flutter/widgets.dart';

/// Shared form validators.
enum IdentifierKind { empty, email, phone, unknown }

abstract final class Validators {
  static final _emailPattern = RegExp(r'^[\w.\-+]+@[\w\-]+(\.[\w\-]+)+$');
  static final _phoneCharacters = RegExp(r'^[+]?[\d\s()\-]+$');

  /// Detects whether the shared sign-in field holds an email or a phone.
  static IdentifierKind identifierKind(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return IdentifierKind.empty;
    if (trimmed.contains('@')) return IdentifierKind.email;
    if (_phoneCharacters.hasMatch(trimmed)) return IdentifierKind.phone;
    return IdentifierKind.unknown;
  }

  static String? identifier(String? value) {
    switch (identifierKind(value)) {
      case IdentifierKind.empty:
        return 'Enter your email or phone number';
      case IdentifierKind.email:
        return email(value);
      case IdentifierKind.phone:
        return phone(value);
      case IdentifierKind.unknown:
        return 'Enter a valid email or phone number';
    }
  }

  static String? name(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter your full name';
    if (trimmed.length < 2) return 'Enter a valid name';
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter your email address';
    if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return 'Enter your phone number';
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    return phone(value);
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Create a password';
    if (password.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  static String? Function(String?) confirmPassword(
    TextEditingController password,
  ) {
    return (String? value) {
      if (value == null || value.isEmpty) return 'Confirm your password';
      if (value != password.text) return 'Passwords do not match';
      return null;
    };
  }
}
