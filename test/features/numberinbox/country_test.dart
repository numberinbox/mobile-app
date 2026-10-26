import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';

void main() {
  final thailand = countryForRegionCode('TH');

  test('Indian national digits are not a country prefix', () {
    expect(countryForRegionCode('IN').isValidPhone('9123456789'), isTrue);
    expect(countryForRegionCode('IN').parseE164('9123456789'), '+919123456789');
  });

  group('countryForRegionCode', () {
    test('resolves US region', () {
      final country = countryForRegionCode('US');
      expect(country.code, 'US');
      expect(country.dialCode, '+1');
    });

    test('is case-insensitive', () {
      expect(countryForRegionCode('th').code, 'TH');
      expect(countryForRegionCode('us').code, 'US');
    });

    test('falls back to Thailand for null', () {
      final country = countryForRegionCode(null);
      expect(country.code, 'TH');
      expect(country.dialCode, '+66');
    });

    test('falls back to Thailand for unknown code', () {
      expect(countryForRegionCode('XX').code, 'TH');
      expect(countryForRegionCode('').code, 'TH');
    });
  });

  group('defaultCountry', () {
    test('honors explicit region override', () {
      expect(defaultCountry(regionOverride: 'US').code, 'US');
      expect(defaultCountry(regionOverride: 'TH').code, 'TH');
    });

    test('resolves device locale to a known country', () {
      expect(countries.map((c) => c.code), contains(defaultCountry().code));
    });
  });

  group('TH local phone validation (M1 contract)', () {
    // The OTP generator issues ordinary Thai mobile numbers; users type them
    // locally with the leading zero. The validation input is the local string
    // exactly as typed; '+66' canonical strings are a different representation
    // and never an equivalent substitute for these cases.
    const localMobiles = {
      '0612345678': '+66612345678',
      '066 123 4567': '+66661234567',
      '0812345678': '+66812345678',
      '0912345678': '+66912345678',
    };

    test('local mobile input with a leading zero validates', () {
      for (final local in localMobiles.keys) {
        expect(thailand.isValidPhone(local), isTrue,
            reason: 'local input "$local" should validate');
      }
    });

    test('local input round-trips to the canonical E.164', () {
      for (final entry in localMobiles.entries) {
        expect(thailand.parseE164(entry.key), entry.value,
            reason: '"${entry.key}" must canonicalize to ${entry.value}');
      }
    });

    test('validation is independent of separators in the local input', () {
      expect(thailand.isValidPhone('081-234-5678'), isTrue);
      expect(thailand.isValidPhone('081 234 5678'), isTrue);
    });

    test('an extra national digit is invalid', () {
      for (final local in localMobiles.keys) {
        final tooLong = '${local}9';
        expect(thailand.isValidPhone(tooLong), isFalse,
            reason: '"$tooLong" must not validate');
      }
    });

    test('empty and non-numeric local input is invalid', () {
      expect(thailand.isValidPhone(''), isFalse);
      expect(thailand.isValidPhone('0812'), isFalse);
      expect(thailand.isValidPhone('abcdefghij'), isFalse);
    });

    test('a foreign local number does not validate as TH', () {
      expect(thailand.isValidPhone('02012345678'), isFalse,
          reason: 'a leading-zero UK-style local number is not a TH mobile');
    });
  });
}
