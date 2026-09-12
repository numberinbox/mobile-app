import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';

void main() {
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
}
