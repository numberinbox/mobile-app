import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:fcm/model/device_client_id.dart';
import 'package:fcm/model/fcm_token.dart';
import 'package:fcm/model/firebase_registration.dart';
import 'package:fcm/model/firebase_registration_expired_time.dart';
import 'package:fcm/model/firebase_registration_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/register_new_firebase_registration_token_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/delete_firebase_registration_cache_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/get_stored_firebase_registration_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/register_platform_fcm_token_interactor.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/store_firebase_registration_interator.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/controller/fcm_token_controller.dart';

import 'fcm_token_controller_test.mocks.dart';

@GenerateMocks([
  RegisterPlatformFcmTokenInteractor,
  GetStoredFirebaseRegistrationInteractor,
  StoreFirebaseRegistrationInteractor,
  DeleteFirebaseRegistrationCacheInteractor,
])
void main() {
  late MockRegisterPlatformFcmTokenInteractor registerPlatformInteractor;
  late MockGetStoredFirebaseRegistrationInteractor getStoredInteractor;
  late MockStoreFirebaseRegistrationInteractor storeInteractor;
  late MockDeleteFirebaseRegistrationCacheInteractor deleteCacheInteractor;
  late FcmTokenController controller;

  setUp(() {
    registerPlatformInteractor = MockRegisterPlatformFcmTokenInteractor();
    getStoredInteractor = MockGetStoredFirebaseRegistrationInteractor();
    storeInteractor = MockStoreFirebaseRegistrationInteractor();
    deleteCacheInteractor = MockDeleteFirebaseRegistrationCacheInteractor();

    Get.testMode = true;
    Get.put<RegisterPlatformFcmTokenInteractor>(registerPlatformInteractor);
    Get.put<GetStoredFirebaseRegistrationInteractor>(getStoredInteractor);
    Get.put<StoreFirebaseRegistrationInteractor>(storeInteractor);
    Get.put<DeleteFirebaseRegistrationCacheInteractor>(deleteCacheInteractor);

    when(registerPlatformInteractor.execute(any))
        .thenAnswer((_) => Stream.fromIterable([]));
    when(getStoredInteractor.execute())
        .thenAnswer((_) => Stream.fromIterable([]));
    when(storeInteractor.execute(any)).thenAnswer((_) => Stream.fromIterable([]));
    when(deleteCacheInteractor.execute())
        .thenAnswer((_) => Stream.fromIterable([]));

    controller = FcmTokenController.instance;
    controller.initialBindingInteractor();
  });

  tearDown(() {
    Get.reset();
  });

  group('FcmTokenController.onFcmTokenChanged', () {
    test(
      'WHEN a new FCM token arrives\n'
      'THEN registers the token on the platform using the install id and stored credential',
      () async {
        controller.onFcmTokenChanged('fcm-token-abc');

        verify(registerPlatformInteractor.execute(FcmToken('fcm-token-abc'))).called(1);
      },
    );

    test(
      'WHEN the platform accepts the registration\n'
      'THEN stores the returned registration in the local cache',
      () async {
        final storedRegistration = FirebaseRegistration(
          id: FirebaseRegistrationId(Id('9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb')),
          token: FcmToken('fcm-token-abc'),
          deviceClientId: DeviceClientId('43b5cf0a-7c1c-4a11-b1c5-2f35e2a3a4b5'),
          expires: FirebaseRegistrationExpiredTime(
            UTCDate(DateTime.parse('2026-11-17T00:00:00Z')),
          ),
        );
        when(registerPlatformInteractor.execute(any)).thenAnswer(
          (_) => Stream.fromIterable([
            Right<Failure, Success>(
              RegisterNewFirebaseRegistrationTokenSuccess(storedRegistration),
            ),
          ]),
        );

        controller.onFcmTokenChanged('fcm-token-abc');
        await untilCalled(registerPlatformInteractor.execute(any));

        verify(storeInteractor.execute(storedRegistration)).called(1);
      },
    );

    test(
      'WHEN the platform refuses the registration\n'
      'THEN clears the stale local registration cache',
      () async {
        when(registerPlatformInteractor.execute(any)).thenAnswer(
          (_) => Stream.fromIterable([
            Left<Failure, Success>(
              RegisterNewFirebaseRegistrationTokenFailure('mailbox_not_pushable'),
            ),
          ]),
        );

        controller.onFcmTokenChanged('fcm-token-abc');
        await untilCalled(registerPlatformInteractor.execute(any));

        verify(deleteCacheInteractor.execute()).called(1);
      },
    );

    test(
      'WHEN Firebase deletes the token\n'
      'THEN reads the stored registration from the local cache without registering',
      () async {
        controller.onFcmTokenChanged(null);

        verifyNever(registerPlatformInteractor.execute(any));
        verify(getStoredInteractor.execute()).called(1);
      },
    );
  });
}
