import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/composer/presentation/extensions/phone_input_extension.dart';

void main() {
  group('PhoneInputExtension::looksLikePhoneNumber', () {
    test('returns true for bare digits', () {
      expect('0951987335'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for digits with + prefix', () {
      expect('+66951987335'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for digits with dashes', () {
      expect('+66-951-987-335'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for digits with spaces', () {
      expect('+66 951 987 335'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for digits with parentheses', () {
      expect('+66 (951) 987-335'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for 0-prefixed local number', () {
      expect('0951987335'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for long digit strings (China 11 digits)', () {
      expect('09519873356'.looksLikePhoneNumber, isTrue);
    });

    test('returns false for email addresses', () {
      expect('user@example.com'.looksLikePhoneNumber, isFalse);
    });

    test('returns false for plain text', () {
      expect('hello'.looksLikePhoneNumber, isFalse);
    });

    test('returns false for empty string', () {
      expect(''.looksLikePhoneNumber, isFalse);
    });

    test('returns false for text with @ but no domain', () {
      expect('user@'.looksLikePhoneNumber, isFalse);
    });

    test('returns false for text with mixed letters and digits', () {
      expect('abc123'.looksLikePhoneNumber, isFalse);
    });

    test('returns true for international format with dashes', () {
      expect('+1-555-123-4567'.looksLikePhoneNumber, isTrue);
    });

    test('returns true for short numbers', () {
      expect('12345'.looksLikePhoneNumber, isTrue);
    });
  });
}
