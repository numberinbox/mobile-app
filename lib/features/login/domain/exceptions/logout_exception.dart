import 'package:core/domain/exceptions/app_base_exception.dart';

class UserCancelledLogoutOIDCFlowException extends AppBaseException {
  UserCancelledLogoutOIDCFlowException([super.message]);

  @override
  String get exceptionName => 'UserCancelledLogoutOIDCFlowException';
}

class RevokeFcmRegistrationFailedException extends AppBaseException {
  RevokeFcmRegistrationFailedException([super.message]);

  @override
  String get exceptionName => 'RevokeFcmRegistrationFailedException';
}
