import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/contacts/phone_contact_mapper.dart';

void main() {
  group('PhoneContactMapper', () {
    late PhoneContactMapper mapper;

    setUp(() {
      mapper = const PhoneContactMapper();
    });

    group('mapPhoneNumber', () {
      test('converts E.164 to email address', () {
        final email = mapper.mapPhoneNumber('+66812345678');
        expect(email, '+66812345678@numberinbox.com');
      });

      test('converts Thai local format to email address', () {
        final email = mapper.mapPhoneNumber('0812345678');
        expect(email, '+66812345678@numberinbox.com');
      });

      test('strips spaces and dashes', () {
        final email = mapper.mapPhoneNumber('+66 8 1234 5678');
        expect(email, '+66812345678@numberinbox.com');
      });

      test('strips parentheses and dots', () {
        final email = mapper.mapPhoneNumber('+66.8.1234.5678');
        expect(email, '+66812345678@numberinbox.com');
      });

      test('returns null for too-short numbers', () {
        final email = mapper.mapPhoneNumber('+6681234');
        expect(email, isNull);
      });

      test('returns null for empty string', () {
        final email = mapper.mapPhoneNumber('');
        expect(email, isNull);
      });

      test('returns null for non-numeric after stripping', () {
        final email = mapper.mapPhoneNumber('+66abcdefghij');
        expect(email, isNull);
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

      test('maps contact with multiple phone numbers', () {
        final results = mapper.mapContact(
          displayName: 'Bob',
          phoneNumbers: ['+66812345678', '0899999999'],
        );
        expect(results, hasLength(2));
        expect(results![0].email, '+66812345678@numberinbox.com');
        expect(results[1].email, '+66899999999@numberinbox.com');
      });

      test('skips invalid phone numbers in contact', () {
        final results = mapper.mapContact(
          displayName: 'Charlie',
          phoneNumbers: ['+66812345678', '123', ''],
        );
        expect(results, hasLength(1));
        expect(results![0].email, '+66812345678@numberinbox.com');
      });

      test('returns null when all numbers invalid', () {
        final results = mapper.mapContact(
          displayName: 'Dave',
          phoneNumbers: ['123', ''],
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
        expect(results[1].email, '+66899999999@numberinbox.com');
      });

      test('skips contacts with no valid numbers', () {
        final contacts = [
          const RawContact(displayName: 'Alice', phoneNumbers: ['+66812345678']),
          const RawContact(displayName: 'NoPhone', phoneNumbers: []),
          const RawContact(displayName: 'BadPhone', phoneNumbers: ['123']),
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
