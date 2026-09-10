import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:model/contact/contact.dart';
import 'package:tmail_ui_user/features/composer/domain/repository/contact_repository.dart';
import 'package:tmail_ui_user/features/composer/domain/state/get_all_device_contacts_state.dart';

class GetAllDeviceContactsInteractor {
  final ContactRepository _contactRepository;

  GetAllDeviceContactsInteractor(this._contactRepository);

  Future<Either<Failure, Success>> execute() async {
    try {
      final contacts = await _contactRepository.getAllContacts();
      final listEmailAddress = contacts
          .map((contact) => contact.toEmailAddress())
          .toList();
      return Right<Failure, Success>(GetAllDeviceContactsSuccess(listEmailAddress));
    } catch (exception) {
      return Left<Failure, Success>(GetAllDeviceContactsFailure(exception));
    }
  }
}
