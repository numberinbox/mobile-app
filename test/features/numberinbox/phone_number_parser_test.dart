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
}
