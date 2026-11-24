import 'dart:math';

/// Utility methods for generating secure temporary passwords for staff onboarding.
class PasswordUtils {
  const PasswordUtils._();

  /// Generates a secure 8-character temporary password.
  ///
  /// If [digitsOnly] is true, generates an 8-digit numeric code (e.g. '84920173')
  /// suitable for quick mobile input.
  /// If [digitsOnly] is false, uses an unambiguous alphanumeric character set.
  static String generateTempPassword({int length = 8, bool digitsOnly = true}) {
    assert(length >= 6, 'Firebase Auth requires at least 6 characters for passwords.');
    final rnd = Random.secure();

    if (digitsOnly) {
      const digits = '0123456789';
      // Ensure the first character is 1-9 so it's a solid 8-digit number string
      final first = (rnd.nextInt(9) + 1).toString();
      final rest = List.generate(length - 1, (_) => digits[rnd.nextInt(digits.length)]).join();
      return '$first$rest';
    }

    // Unambiguous alphanumeric set (excluding 0, O, 1, l, I)
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
