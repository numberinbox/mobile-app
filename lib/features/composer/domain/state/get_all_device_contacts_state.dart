import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';

class GetAllDeviceContactsSuccess extends UIState {
  final List<EmailAddress> listEmailAddress;

  GetAllDeviceContactsSuccess(this.listEmailAddress);

  @override
  List<Object> get props => [listEmailAddress];
}

class GetAllDeviceContactsFailure extends FeatureFailure {
  GetAllDeviceContactsFailure(dynamic exception) : super(exception: exception);
}
