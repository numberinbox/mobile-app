import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/contacts/phone_contact_mapper.dart';

void main() {
  group('PhoneContactMapper', () {
    late PhoneContactMapper mapper;

    setUp(() {
      mapper = const PhoneContactMapper();
    });

    group('mapRecipientPhoneNumber', () {
      test('converts explicit international to canonical address', () {
        expect(
          mapper.mapRecipientPhoneNumber('+66812345678'),
          '+66812345678@numberinbox.com',
        );
      });

      test('strips spaces and dashes from explicit international', () {
        expect(
          mapper.mapRecipientPhoneNumber('+66 8 1234 5678'),
          '+66812345678@numberinbox.com',
        );
      });

      test('strips parentheses and dots from explicit international', () {
        expect(
          mapper.mapRecipientPhoneNumber('+66.8.1234.5678'),
          '+66812345678@numberinbox.com',
        );
      });

      test('preserves local numbers raw without a domain', () {
        expect(mapper.mapRecipientPhoneNumber('0812345678'), '0812345678');
        expect(mapper.mapRecipientPhoneNumber('029009119'), '029009119');
      });

      test('preserves formatted local numbers trimmed but otherwise raw', () {
        expect(
          mapper.mapRecipientPhoneNumber(' 095-198-7335 '),
          '095-198-7335',
        );
      });

      test('preserves phone-shaped input that cannot resolve', () {
        expect(mapper.mapRecipientPhoneNumber('+6681234'), '+6681234');
        expect(mapper.mapRecipientPhoneNumber('12345'), '12345');
      });

      test('returns null for empty string', () {
        expect(mapper.mapRecipientPhoneNumber(''), isNull);
      });

      test('returns null for non-phone content', () {
        expect(mapper.mapRecipientPhoneNumber('abc'), isNull);
        expect(mapper.mapRecipientPhoneNumber('+66abcdefghij'), isNull);
        expect(
          mapper.mapRecipientPhoneNumber('someone@example.com'),
          isNull,
        );
      });
    });

    group('mapContact', () {
      test('maps contact with single phone number', () {
        final results = mapper.mapContact(
          displayName: 'Alice',
          phoneNumbers: ['+66812345678'],
        );
        expect(results, isNotNull);
        expect(results, hasLength(1));
        expect(results![0].displayName, 'Alice');
        expect(results[0].email, '+66812345678@numberinbox.com');
      });

      test('keeps resolved and unresolved numbers with the contact name', () {
        final results = mapper.mapContact(
          displayName: 'Bob',
          phoneNumbers: ['+66812345678', '0899999999'],
        );
        expect(results, hasLength(2));
        expect(results![0].email, '+66812345678@numberinbox.com');
        expect(results[0].displayName, 'Bob');
        expect(results[1].email, '0899999999');
        expect(results[1].displayName, 'Bob');
      });

      test('preserves unresolvable phone-shaped input instead of dropping it', () {
        final results = mapper.mapContact(
          displayName: 'Charlie',
          phoneNumbers: ['+66812345678', '123', ''],
        );
        expect(results, hasLength(2));
        expect(results![0].email, '+66812345678@numberinbox.com');
        expect(results[1].email, '123');
      });

      test('returns null when every number is empty or non-phone', () {
        final results = mapper.mapContact(
          displayName: 'Dave',
          phoneNumbers: ['abc', ''],
        );
        expect(results, isNull);
      });
    });

    group('mapContacts', () {
      test('maps multiple contacts', () {
        final contacts = [
          const RawContact(displayName: 'Alice', phoneNumbers: ['+66812345678']),
          const RawContact(displayName: 'Bob', phoneNumbers: ['0899999999']),
        ];
        final results = mapper.mapContacts(contacts);
        expect(results, hasLength(2));
        expect(results[0].displayName, 'Alice');
        expect(results[0].email, '+66812345678@numberinbox.com');
        expect(results[1].displayName, 'Bob');
        expect(results[1].email, '0899999999');
      });

      test('skips contacts with no phone-shaped numbers', () {
        final contacts = [
          const RawContact(displayName: 'Alice', phoneNumbers: ['+66812345678']),
          const RawContact(displayName: 'NoPhone', phoneNumbers: []),
          const RawContact(displayName: 'BadPhone', phoneNumbers: ['abc']),
        ];
        final results = mapper.mapContacts(contacts);
        expect(results, hasLength(1));
        expect(results[0].displayName, 'Alice');
      });

      test('returns empty list for empty input', () {
        final results = mapper.mapContacts([]);
        expect(results, isEmpty);
      });
    });
  });
}
