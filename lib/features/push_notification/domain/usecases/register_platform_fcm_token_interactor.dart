
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:fcm/model/device_client_id.dart';
import 'package:fcm/model/fcm_token.dart';
import 'package:fcm/model/firebase_registration.dart';
import 'package:fcm/model/firebase_registration_expired_time.dart';
import 'package:fcm/model/firebase_registration_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/push_notification/data/local/fcm_install_id_provider.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/fcm_registration_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/register_new_firebase_registration_token_state.dart';

/// Carries the FCM token to the NumberInbox platform via
/// `POST /v1/fcm-registrations`, in the place the JMAP
/// `FirebaseRegistration/set` path used to hold.
///
/// The `deviceClientId` is the stable install id — not the token hash — so the
/// platform keeps treating the installation as one device across token
/// rotations. Authentication reuses the mailbox Basic credential already
/// stored on this device, and the success state is the same
/// [RegisterNewFirebaseRegistrationTokenSuccess] the JMAP interactor emitted,
/// so downstream caching keeps working unchanged.
class RegisterPlatformFcmTokenInteractor {

  final FcmRegistrationApi _fcmRegistrationApi;
  final FcmInstallIdProvider _fcmInstallIdProvider;
  final CredentialRepository _credentialRepository;

  RegisterPlatformFcmTokenInteractor(
    this._fcmRegistrationApi,
    this._fcmInstallIdProvider,
    this._credentialRepository
  );

  Stream<Either<Failure, Success>> execute(FcmToken newFcmToken) async* {
    try {
      yield Right<Failure, Success>(RegisterNewFirebaseRegistrationTokenLoading());
      final authenticationInfoCache = await _credentialRepository.getAuthenticationInfoStored();
      final installId = await _fcmInstallIdProvider.getInstallId();
      if (installId == null) {
        throw StateError('could not persist the installation id');
      }
      final payload = await _fcmRegistrationApi.register(
        token: newFcmToken.value,
        deviceClientId: installId,
        username: authenticationInfoCache.username,
        password: authenticationInfoCache.password,
      );
      final firebaseRegistration = FirebaseRegistration(
        id: FirebaseRegistrationId(Id(payload.registrationId)),
        token: newFcmToken,
        deviceClientId: DeviceClientId(installId),
        expires: FirebaseRegistrationExpiredTime(UTCDate(payload.expiresAt)),
      );
      yield Right<Failure, Success>(
        RegisterNewFirebaseRegistrationTokenSuccess(firebaseRegistration));
    } catch (e) {
      yield Left<Failure, Success>(RegisterNewFirebaseRegistrationTokenFailure(e));
    }
  }
}
