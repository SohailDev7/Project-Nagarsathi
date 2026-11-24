import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/utils/password_utils.dart';

void main() {
  group('PasswordUtils', () {
    test('generateTempPassword generates 8 digits by default', () {
      final pwd = PasswordUtils.generateTempPassword();
      expect(pwd.length, 8);
      expect(RegExp(r'^[1-9][0-9]{7}$').hasMatch(pwd), isTrue);
    });

    test('generateTempPassword with custom length', () {
      final pwd = PasswordUtils.generateTempPassword(length: 10);
      expect(pwd.length, 10);
      expect(RegExp(r'^[1-9][0-9]{9}$').hasMatch(pwd), isTrue);
    });

    test('generateTempPassword alphanumeric produces valid characters', () {
      final pwd = PasswordUtils.generateTempPassword(length: 8, digitsOnly: false);
      expect(pwd.length, 8);
      expect(RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(pwd), isTrue);
    });
  });
}
