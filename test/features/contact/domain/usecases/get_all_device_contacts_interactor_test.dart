import 'package:flutter_test/flutter_test.dart';
import 'package:model/contact/contact.dart';
import 'package:model/contact/device_contact.dart';
import 'package:tmail_ui_user/features/composer/domain/repository/contact_repository.dart';
import 'package:tmail_ui_user/features/composer/domain/state/get_all_device_contacts_state.dart';
import 'package:tmail_ui_user/features/composer/domain/usecases/get_all_device_contacts_interactor.dart';

class MockContactRepository implements ContactRepository {
  List<Contact>? allContactsResult;
  Exception? exception;

  @override
  Future<List<Contact>> getAllContacts() async {
    if (exception != null) throw exception!;
    return allContactsResult ?? [];
  }

  @override
  Future<List<Contact>> getContactSuggestions(dynamic autoCompletePattern) async {
    return [];
  }
}

void main() {
  late MockContactRepository mockRepository;
  late GetAllDeviceContactsInteractor interactor;

  setUp(() {
    mockRepository = MockContactRepository();
    interactor = GetAllDeviceContactsInteractor(mockRepository);
  });

  group('GetAllDeviceContactsInteractor::execute', () {
    test('returns success with contacts when repository has data', () async {
      final contacts = [
        DeviceContact('Alice', 'alice@example.com'),
        DeviceContact('Bob', '+66812345678@numberinbox.com'),
      ];
      mockRepository.allContactsResult = contacts;

      final result = await interactor.execute();

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success, got failure'),
        (success) {
          expect(success, isA<GetAllDeviceContactsSuccess>());
          final list = (success as GetAllDeviceContactsSuccess).listEmailAddress;
          expect(list, hasLength(2));
          expect(list[0].email, 'alice@example.com');
          expect(list[1].email, '+66812345678@numberinbox.com');
        },
      );
    });

    test('returns success with empty list when no contacts', () async {
      mockRepository.allContactsResult = [];

      final result = await interactor.execute();

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success, got failure'),
        (success) {
          expect(success, isA<GetAllDeviceContactsSuccess>());
          final list = (success as GetAllDeviceContactsSuccess).listEmailAddress;
          expect(list, isEmpty);
        },
      );
    });

    test('returns failure when repository throws', () async {
      mockRepository.exception = Exception('permission denied');

      final result = await interactor.execute();

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<GetAllDeviceContactsFailure>()),
        (success) => fail('Expected failure, got success'),
      );
    });
  });
}
