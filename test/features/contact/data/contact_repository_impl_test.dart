import 'package:flutter_test/flutter_test.dart';
import 'package:model/autocomplete/auto_complete_pattern.dart';
import 'package:model/contact/contact.dart';
import 'package:model/contact/device_contact.dart';
import 'package:tmail_ui_user/features/composer/data/datasource/contact_datasource.dart';
import 'package:tmail_ui_user/features/composer/data/repository/contact_repository_impl.dart';

class MockContactDataSource implements ContactDataSource {
  List<Contact>? getAllContactsResult;
  List<Contact>? getContactSuggestionsResult;
  Exception? exception;

  @override
  Future<List<Contact>> getAllContacts() async {
    if (exception != null) throw exception!;
    return getAllContactsResult ?? [];
  }

  @override
  Future<List<Contact>> getContactSuggestions(AutoCompletePattern autoCompletePattern) async {
    if (exception != null) throw exception!;
    return getContactSuggestionsResult ?? [];
  }
}

void main() {
  late MockContactDataSource mockDataSource;
  late ContactRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockContactDataSource();
    repository = ContactRepositoryImpl(mockDataSource);
  });

  group('ContactRepositoryImpl::getAllContacts', () {
    test('returns all contacts from datasource', () async {
      final contacts = [
        DeviceContact('Alice', 'alice@example.com'),
        DeviceContact('Bob', '+66812345678@numberinbox.com'),
      ];
      mockDataSource.getAllContactsResult = contacts;

      final result = await repository.getAllContacts();

      expect(result, contacts);
      expect(result, hasLength(2));
    });

    test('returns empty list when datasource returns empty', () async {
      mockDataSource.getAllContactsResult = [];

      final result = await repository.getAllContacts();

      expect(result, isEmpty);
    });

    test('propagates errors from datasource', () async {
      mockDataSource.exception = Exception('db error');

      expect(
        () => repository.getAllContacts(),
        throwsException,
      );
    });
  });
}
