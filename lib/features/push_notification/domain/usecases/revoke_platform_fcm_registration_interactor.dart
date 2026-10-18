
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:fcm/model/firebase_registration_id.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/fcm_registration_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/destroy_firebase_registration_state.dart';

/// Deletes this device's FCM registration on the NumberInbox platform via
/// `DELETE /v1/fcm-registrations/{registrationId}`, in the place the JMAP
/// `FirebaseRegistration/destroy` path used to hold.
///
/// Authentication reuses the mailbox Basic credential already stored on this
/// device. Emissions reuse the `DestroyFirebaseRegistration*` states so the
/// sign-out flow keeps working unchanged.
class RevokePlatformFcmRegistrationInteractor {

  final FcmRegistrationApi _fcmRegistrationApi;
  final CredentialRepository _credentialRepository;

  RevokePlatformFcmRegistrationInteractor(
    this._fcmRegistrationApi,
    this._credentialRepository
  );

  Stream<Either<Failure, Success>> execute(FirebaseRegistrationId registrationId) async* {
    try {
      yield Right<Failure, Success>(DestroyFirebaseRegistrationLoading());
      final authenticationInfoCache = await _credentialRepository.getAuthenticationInfoStored();
      await _fcmRegistrationApi.revoke(
        registrationId: registrationId.id.value,
        username: authenticationInfoCache.username,
        password: authenticationInfoCache.password,
      );
      yield Right<Failure, Success>(DestroyFirebaseRegistrationSuccess());
    } catch (e) {
      yield Left<Failure, Success>(DestroyFirebaseRegistrationFailure(e));
    }
  }
}
