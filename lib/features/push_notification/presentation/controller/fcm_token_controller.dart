
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/utils/app_logger.dart';
import 'package:fcm/model/fcm_token.dart';
import 'package:fcm/model/firebase_registration.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/register_new_firebase_registration_token_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/delete_firebase_registration_cache_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_stored_firebase_registration_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/register_platform_fcm_token_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/store_firebase_registration_interator.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/push_base_controller.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

/// Carries the FCM token lifecycle to the NumberInbox platform
/// (`POST`/`DELETE /v1/fcm-registrations`).
class FcmTokenController extends PushBaseController {

  FcmTokenController._internal();

  static final FcmTokenController _instance = FcmTokenController._internal();

  static FcmTokenController get instance => _instance;

  StoreFirebaseRegistrationInteractor? _storeFirebaseRegistrationInteractor;
  RegisterPlatformFcmTokenInteractor? _registerPlatformFcmTokenInteractor;
  GetStoredFirebaseRegistrationInteractor? _getStoredFirebaseRegistrationInteractor;
  DeleteFirebaseRegistrationCacheInteractor? _deleteFirebaseRegistrationCacheInteractor;

  void initialBindingInteractor() {
    _storeFirebaseRegistrationInteractor = getBinding<StoreFirebaseRegistrationInteractor>();
    _registerPlatformFcmTokenInteractor = getBinding<RegisterPlatformFcmTokenInteractor>();
    _getStoredFirebaseRegistrationInteractor = getBinding<GetStoredFirebaseRegistrationInteractor>();
    _deleteFirebaseRegistrationCacheInteractor = getBinding<DeleteFirebaseRegistrationCacheInteractor>();
  }

  void onFcmTokenChanged(String? newToken) {
    // The token is a credential; only its presence is logged.
    log('FcmTokenController::onFcmTokenChanged():newToken: ${newToken != null ? '<fresh-token>' : null}');
    if (newToken != null) {
      _registerFcmTokenOnPlatform(FcmToken(newToken));
    } else {
      _getStoredFirebaseRegistrationFromCache();
    }
  }

  void _registerFcmTokenOnPlatform(FcmToken newFcmToken) {
    if (_registerPlatformFcmTokenInteractor != null) {
      consumeState(_registerPlatformFcmTokenInteractor!.execute(newFcmToken));
    }
  }

  void _getStoredFirebaseRegistrationFromCache() {
    if (_getStoredFirebaseRegistrationInteractor != null) {
      consumeState(_getStoredFirebaseRegistrationInteractor!.execute());
    }
  }

  void _storeFirebaseRegistrationToCache(FirebaseRegistration firebaseRegistration){
    if (_storeFirebaseRegistrationInteractor != null) {
      consumeState(_storeFirebaseRegistrationInteractor!.execute(firebaseRegistration));
    }
  }

  void _deleteFirebaseRegistrationInCache() {
    if (_deleteFirebaseRegistrationCacheInteractor != null) {
      consumeState(_deleteFirebaseRegistrationCacheInteractor!.execute());
    }
  }

  @override
  void handleFailureViewState(Failure failure) {
    // Fixed event name only: the state classes stringify their props
    // (exception payload included) and must not reach a log sink.
    logError('FcmTokenController::handleFailureViewState(): RegisterNewFirebaseRegistrationTokenFailure');
    if (failure is RegisterNewFirebaseRegistrationTokenFailure) {
      _deleteFirebaseRegistrationInCache();
    }
  }

  @override
  void handleSuccessViewState(Success success) {
    // The success state stringifies into the full registration object
    // (token included); log the fixed event name instead.
    log('FcmTokenController::handleSuccessViewState(): RegisterNewFirebaseRegistrationTokenSuccess');
    if (success is RegisterNewFirebaseRegistrationTokenSuccess) {
      _storeFirebaseRegistrationToCache(success.firebaseRegistration);
    }
  }
}
