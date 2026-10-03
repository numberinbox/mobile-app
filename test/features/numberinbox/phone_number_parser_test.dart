import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/phone_number_parser.dart';

void main() {
  group('PhoneNumberParser', () {
    final parser = PhoneNumberParser();

    test('0951987335 with TH -> +66951987335', () {
      expect(parser.parseToE164('0951987335', defaultRegion: 'TH'), '+66951987335');
    });

    test('0951987335 with US -> still +669 via TH fallback for 0-prefix', () {
      expect(parser.parseToE164('0951987335', defaultRegion: 'US'), '+66951987335');
    });

    test('66951987335 without + -> +66951987335 via +cleaned', () {
      expect(parser.parseToE164('66951987335', defaultRegion: 'TH'), '+66951987335');
      expect(parser.parseToE164('66951987335', defaultRegion: 'US'), '+66951987335');
    });

    test('+66951987335 stays', () {
      expect(parser.parseToE164('+66951987335'), '+66951987335');
    });

    test('+66-951987335 hyphen stripped -> +66951987335', () {
      expect(parser.parseToE164('+66-951987335'), '+66951987335');
    });

    test('+66 95 198 7335 spaces stripped -> +66951987335', () {
      expect(parser.parseToE164('+66 95 198 7335'), '+66951987335');
    });

    test('095-198-7335 stripped -> +66951987335 with TH', () {
      expect(parser.parseToE164('095-198-7335', defaultRegion: 'TH'), '+66951987335');
    });

    test('6502530001 US national -> +16502530001', () {
      expect(parser.parseToE164('6502530001', defaultRegion: 'US'), '+16502530001');
    });

    test('invalid -> null', () {
      expect(parser.parseToE164('12345'), isNull);
      expect(parser.parseToE164('abc'), isNull);
      expect(parser.parseToE164(''), isNull);
    });

    test('toEmail creates NumberInbox email', () {
      expect(parser.toEmail('0951987335', defaultRegion: 'TH'), '+66951987335@numberinbox.com');
      expect(parser.toEmail('66951987335'), '+66951987335@numberinbox.com');
      expect(parser.toEmail('+66-951987335'), '+66951987335@numberinbox.com');
      expect(parser.toEmail('12345'), isNull);
    });
  });

  group('PhoneNumberParser.parseRecipientToE164', () {
    final parser = PhoneNumberParser();

    test('029009119 without a selected region stays unresolved', () {
      expect(parser.parseRecipientToE164('029009119'), isNull);
    });

    test('029009119 with TH resolves to +6629009119', () {
      expect(
        parser.parseRecipientToE164('029009119', selectedRegion: 'TH'),
        '+6629009119',
      );
    });

    test('029009119 with US fails without retrying Thailand', () {
      expect(
        parser.parseRecipientToE164('029009119', selectedRegion: 'US'),
        isNull,
      );
    });

    test('explicit + numbers resolve internationally without a region', () {
      expect(parser.parseRecipientToE164('+66951987335'), '+66951987335');
      expect(parser.parseRecipientToE164('+66 95 198 7335'), '+66951987335');
      expect(parser.parseRecipientToE164('+66-951-987-335'), '+66951987335');
      expect(parser.parseRecipientToE164('+66.951.987.335'), '+66951987335');
    });

    test('0066 prefix stays unresolved even with TH selected', () {
      // The installed library rejects `0066951987335` for TH (`006` is not
      // a valid Thai dialing prefix); the parser must not manufacture an
      // address by stripping only `00`.
      expect(
        parser.parseRecipientToE164('0066951987335', selectedRegion: 'TH'),
        isNull,
      );
      expect(parser.parseRecipientToE164('0066951987335'), isNull);
    });

    test('valid regional dialing prefixes resolve through the library', () {
      expect(
        parser.parseRecipientToE164('00166951987335', selectedRegion: 'TH'),
        '+66951987335',
      );
    });

    test('non-00 IDD prefix resolves through the selected region metadata', () {
      expect(
        parser.parseRecipientToE164('01166951987335', selectedRegion: 'US'),
        '+66951987335',
      );
    });

    test('short and malformed input cannot become delivery addresses', () {
      expect(parser.parseRecipientToE164('12345'), isNull);
      expect(
        parser.parseRecipientToE164('12345', selectedRegion: 'TH'),
        isNull,
      );
      expect(parser.parseRecipientToE164('abc'), isNull);
      expect(parser.parseRecipientToE164(''), isNull);
      expect(parser.parseRecipientToE164('+6612345'), isNull);
    });

    test('extensions and unsupported characters are rejected', () {
      expect(parser.parseRecipientToE164('+66951987335 ext 123'), isNull);
      expect(parser.parseRecipientToE164('+66951987335;ext=1'), isNull);
      expect(parser.parseRecipientToE164('++66951987335'), isNull);
      expect(parser.parseRecipientToE164('66+66951987335'), isNull);
      expect(parser.parseRecipientToE164('029-009-119#'), isNull);
    });
  });
}
