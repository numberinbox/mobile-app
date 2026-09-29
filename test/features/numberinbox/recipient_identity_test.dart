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
