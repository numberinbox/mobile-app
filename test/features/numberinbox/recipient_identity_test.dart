import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/contact/device_contact.dart';
import 'package:tmail_ui_user/features/numberinbox/recipient_identity.dart';

/// Canonical recipient identity: one deliverable address is one recipient,
/// no matter how many platform records, casings, or formats name it.
void main() {
  group('canonicalRecipientKey', () {
    test('trims whitespace and lowercases', () {
      expect(
        canonicalRecipientKey('  Ms.Somluck@Example.COM  '),
        'ms.somluck@example.com',
      );
    });

    test('equivalent formatted phones map to one +E164 entry', () {
      const variants = [
        '+66812345678@numberinbox.com',
        '+66 81 234 5678@numberinbox.com',
        '+66-81-234-5678@NUMBERINBOX.COM',
      ];
      final keys = variants.map(canonicalRecipientKey).toSet();
      expect(keys, {'+66812345678@numberinbox.com'});
    });

    test('unparseable numberinbox local part falls back to lowered trim', () {
      expect(
        canonicalRecipientKey('  NOT-A-NUMBER@numberinbox.com '),
        'not-a-number@numberinbox.com',
      );
    });

    test('non-phone local part on our domain stays a plain address', () {
      expect(
        canonicalRecipientKey('Somluck@numberinbox.com'),
        'somluck@numberinbox.com',
      );
    });
  });

  group('unresolved phone identity', () {
    test('raw local and domain-carried local share one key', () {
      expect(
        canonicalRecipientKey('029009119'),
        canonicalRecipientKey('029009119@numberinbox.com'),
      );
    });

    test('formatting differences do not split unresolved identity', () {
      expect(
        canonicalRecipientKey('029-009-119'),
        canonicalRecipientKey('029009119'),
      );
      expect(
        canonicalRecipientKey('(02) 900 9119'),
        canonicalRecipientKey('029009119'),
      );
    });

    test('unresolved local stays distinct from the resolved address', () {
      expect(
        canonicalRecipientKey('029009119'),
        isNot(canonicalRecipientKey('+6629009119@numberinbox.com')),
      );
    });

    test('invalid explicit international stays distinct from valid ones', () {
      expect(
        canonicalRecipientKey('+6612345@numberinbox.com'),
        isNot(canonicalRecipientKey('+66812345678@numberinbox.com')),
      );
    });

    test('unresolved duplicates collapse keeping the first useful name', () {
      final result = deduplicateRecipients([
        EmailAddress('', '029-009-119'),
        EmailAddress('Somluck', '029009119@numberinbox.com'),
      ]);
      expect(result, hasLength(1));
      expect(result.single.name, 'Somluck');
    });

    test('resolved duplicates merge to one canonical address', () {
      final result = deduplicateRecipients([
        EmailAddress('Somluck', '+6629009119@numberinbox.com'),
        EmailAddress('Somluck', '+66 29 009 119@numberinbox.com'),
      ]);
      expect(result, hasLength(1));
      expect(
        result.single.email,
        '+6629009119@numberinbox.com',
      );
    });
  });

  group('preparePhoneRecipient', () {
    test('upgrades explicit international to canonical, keeping the name', () {
      final result = preparePhoneRecipient(
        EmailAddress('Somluck', '+66 29 009 119'),
      );
      expect(result.email, '+6629009119@numberinbox.com');
      expect(result.name, 'Somluck');
    });

    test('keeps unresolved numbers raw with the name retained', () {
      final result = preparePhoneRecipient(
        EmailAddress('Somluck', ' 02 900 9119 '),
      );
      expect(result.email, '02 900 9119');
      expect(result.name, 'Somluck');
    });

    test('normalizes empty names to null', () {
      final result = preparePhoneRecipient(
        EmailAddress('  ', '029009119'),
      );
      expect(result.email, '029009119');
      expect(result.name, isNull);
    });

    test('passes ordinary emails through trimmed', () {
      final result = preparePhoneRecipient(
        EmailAddress('Person', '  Person@Example.COM  '),
      );
      expect(result.email, 'Person@Example.COM');
      expect(result.name, 'Person');
    });
  });

  group('isPhoneShaped', () {
    test('accepts digits with phone formatting', () {
      expect(isPhoneShaped('029009119'), isTrue);
      expect(isPhoneShaped('+66 95 198 7335'), isTrue);
      expect(isPhoneShaped('(02) 900-9119'), isTrue);
      expect(isPhoneShaped('12345'), isTrue);
    });

    test('rejects empty, non-phone, and digitless input', () {
      expect(isPhoneShaped(''), isFalse);
      expect(isPhoneShaped('   '), isFalse);
      expect(isPhoneShaped('Somluck'), isFalse);
      expect(isPhoneShaped('abc-def'), isFalse);
      expect(isPhoneShaped('() - .'), isFalse);
      expect(isPhoneShaped('someone@example.com'), isFalse);
    });
  });

  group('deduplicateRecipients', () {
    test('duplicate emails with case/whitespace differences collapse', () {
      final result = deduplicateRecipients([
        EmailAddress('Ms Somluck', 'Ms.Somluck@example.com'),
        EmailAddress('Other Name', '  ms.somluck@EXAMPLE.com '),
      ]);
      expect(result, hasLength(1));
      expect(result.single.email, 'Ms.Somluck@example.com');
      expect(result.single.name, 'Ms Somluck');
    });

    test('empty display name is upgraded from a later duplicate', () {
      final result = deduplicateRecipients([
        EmailAddress('', 'a@example.com'),
        EmailAddress(' Somluck ', 'A@EXAMPLE.COM'),
      ]);
      expect(result, hasLength(1));
      expect(result.single.name, ' Somluck ');
    });

    test('same display name with different numbers stays multiple', () {
      final result = deduplicateRecipients([
        EmailAddress('Somluck', '+66812345678@numberinbox.com'),
        EmailAddress('Somluck', '+66842327391@numberinbox.com'),
      ]);
      expect(result, hasLength(2));
    });

    test('same canonical number from different formats stays one', () {
      final result = deduplicateRecipients([
        EmailAddress('A', '+66812345678@numberinbox.com'),
        EmailAddress('B', '+66 81 234 5678@numberinbox.com'),
      ]);
      expect(result, hasLength(1));
      expect(result.single.name, 'A');
    });

    test('preserves first-seen order', () {
      final result = deduplicateRecipients([
        EmailAddress('B', 'b@example.com'),
        EmailAddress('A', 'a@example.com'),
        EmailAddress('B2', 'B@EXAMPLE.COM'),
      ]);
      expect(result.map((e) => e.email), ['b@example.com', 'a@example.com']);
    });
  });

  group('deduplicateContacts', () {
    test('three platform records for one number produce one contact', () {
      final result = deduplicateContacts([
        DeviceContact('Karrakad', '+66842327391@numberinbox.com'),
        DeviceContact('Karrakad', '+66 84 232 7391@numberinbox.com'),
        DeviceContact('', '+66842327391@NUMBERINBOX.COM'),
      ]);
      expect(result, hasLength(1));
      expect(result.single.displayName, 'Karrakad');
    });

    test('one contact with two numbers remains two rows', () {
      final result = deduplicateContacts([
        DeviceContact('Jamie', '+61417609314@numberinbox.com'),
        DeviceContact('Jamie', '+66812345678@numberinbox.com'),
      ]);
      expect(result, hasLength(2));
    });
  });
}
