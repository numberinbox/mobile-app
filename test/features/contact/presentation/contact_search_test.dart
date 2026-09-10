import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:model/extensions/email_address_extension.dart';
import 'package:tmail_ui_user/features/contact/presentation/utils/contact_search_filter.dart';

void main() {
  final manish = EmailAddress('Manish Thakur', '+918860997941@numberinbox.com');
  final john = EmailAddress('John Doe', 'john@example.com');
  final alice = EmailAddress('Alice Smith', 'alice@numberinbox.com');
  final allContacts = [manish, john, alice];

  group('filterLocalContacts', () {
    test('filters by name case-insensitive', () {
      final result = filterLocalContacts('tha', allContacts);
      expect(result, hasLength(1));
      expect(result[0].displayName, 'Manish Thakur');
    });

    test('filters by name full match', () {
      final result = filterLocalContacts('john', allContacts);
      expect(result, hasLength(1));
      expect(result[0].displayName, 'John Doe');
    });

    test('filters by email', () {
      final result = filterLocalContacts('numberinbox', allContacts);
      expect(result, hasLength(2));
      expect(result[0].displayName, 'Manish Thakur');
      expect(result[1].displayName, 'Alice Smith');
    });

    test('filters by partial phone in email', () {
      final result = filterLocalContacts('91886', allContacts);
      expect(result, hasLength(1));
      expect(result[0].displayName, 'Manish Thakur');
    });

    test('returns empty when no match', () {
      final result = filterLocalContacts('xyz', allContacts);
      expect(result, isEmpty);
    });

    test('returns all for empty query', () {
      final result = filterLocalContacts('', allContacts);
      expect(result, hasLength(3));
    });
  });

  group('mergeContactResults', () {
    test('puts local matches first', () {
      final result = mergeContactResults(
        localMatches: [manish],
        serverResults: [john],
        query: 'tha',
      );
      expect(result, hasLength(2));
      expect(result[0].displayName, 'Manish Thakur');
      expect(result[1].displayName, 'John Doe');
    });

    test('deduplicates by email', () {
      final result = mergeContactResults(
        localMatches: [manish],
        serverResults: [manish],
        query: 'tha',
      );
      expect(result, hasLength(1));
      expect(result[0].displayName, 'Manish Thakur');
    });

    test('adds raw email if query is email and not in results', () {
      final result = mergeContactResults(
        localMatches: [],
        serverResults: [],
        query: 'test@foo.com',
      );
      expect(result, hasLength(1));
      expect(result[0].emailAddress, 'test@foo.com');
    });

    test('does not add raw email if already present', () {
      final result = mergeContactResults(
        localMatches: [manish],
        serverResults: [],
        query: '+918860997941@numberinbox.com',
      );
      expect(result, hasLength(1));
      expect(result[0].displayName, 'Manish Thakur');
    });
  });
}
