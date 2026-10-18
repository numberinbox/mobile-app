import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:fcm/model/device_client_id.dart';
import 'package:fcm/model/fcm_token.dart';
import 'package:fcm/model/firebase_registration.dart';
import 'package:fcm/model/firebase_registration_expired_time.dart';
import 'package:fcm/model/firebase_registration_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/push_notification/data/local/fcm_install_id_provider.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/fcm_registration_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/register_new_firebase_registration_token_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/register_platform_fcm_token_interactor.dart';

import 'register_platform_fcm_token_interactor_test.mocks.dart';

@GenerateMocks([CredentialRepository])
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late SharedPreferences sharedPreferences;
  late MockCredentialRepository credentialRepository;
  late RegisterPlatformFcmTokenInteractor interactor;

  const storedInstallId = '43b5cf0a-7c1c-4a11-b1c5-2f35e2a3a4b5';
  const storedUsername = '+66841234567@numberinbox.com';
  const storedPassword = 'stalwart-password';
  final registrationId = Id('9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb');
  final expiresAt = DateTime.parse('2026-11-17T00:00:00Z');

  setUp(() async {
    dio = Dio(BaseOptions())..options.baseUrl = 'https://example.com';
    dioAdapter = DioAdapter(dio: dio);
    SharedPreferences.setMockInitialValues({
      FcmInstallIdProvider.installIdKey: storedInstallId,
    });
    sharedPreferences = await SharedPreferences.getInstance();
    credentialRepository = MockCredentialRepository();
    when(credentialRepository.getAuthenticationInfoStored()).thenAnswer(
      (_) async => AuthenticationInfoCache(storedUsername, storedPassword),
    );
    interactor = RegisterPlatformFcmTokenInteractor(
      FcmRegistrationApi(dio),
      FcmInstallIdProvider(sharedPreferences),
      credentialRepository,
    );
  });

  group('RegisterPlatformFcmTokenInteractor.execute', () {
    test(
      'WHEN the platform accepts the token\n'
      'THEN emits Loading then Success carrying the registration id, expiry and install id',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(202, {
            'registrationId': registrationId.value,
            'expiresAt': '2026-11-17T00:00:00Z',
          }),
          data: {
            'token': 'fcm-token-abc',
            'deviceClientId': storedInstallId,
            'type': 'email',
          },
          headers: {
            'Authorization':
                'Basic KzY2ODQxMjM0NTY3QG51bWJlcmluYm94LmNvbTpzdGFsd2FydC1wYXNzd29yZA==',
          },
        );

        expect(
          interactor.execute(FcmToken('fcm-token-abc')),
          emitsInOrder([
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'loading',
              isA<RegisterNewFirebaseRegistrationTokenLoading>(),
            ),
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'success',
              isA<RegisterNewFirebaseRegistrationTokenSuccess>().having(
                (success) => success.firebaseRegistration,
                'registration',
                FirebaseRegistration(
                  id: FirebaseRegistrationId(registrationId),
                  token: FcmToken('fcm-token-abc'),
                  deviceClientId: DeviceClientId(storedInstallId),
                  expires: FirebaseRegistrationExpiredTime(UTCDate(expiresAt)),
                ),
              ),
            ),
          ]),
        );
      },
    );

    test(
      'WHEN no credential is stored\n'
      'THEN emits Failure without contacting the platform',
      () async {
        when(credentialRepository.getAuthenticationInfoStored())
            .thenThrow(Exception('no credential on a signed-out device'));

        expect(
          interactor.execute(FcmToken('fcm-token-abc')),
          emitsInOrder([
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'loading',
              isA<RegisterNewFirebaseRegistrationTokenLoading>(),
            ),
            isA<Left<dynamic, dynamic>>().having(
              (either) => either.value,
              'failure',
              isA<RegisterNewFirebaseRegistrationTokenFailure>(),
            ),
          ]),
        );
      },
    );

    test(
      'WHEN the platform rejects an unclaimed mailbox\n'
      'THEN emits Failure with the backend error',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(409, {
            'error': 'mailbox_not_pushable',
            'message': 'mailbox is not claimed or has no linked account',
          }),
          data: {
            'token': 'fcm-token-abc',
            'deviceClientId': storedInstallId,
            'type': 'email',
          },
        );

        expect(
          interactor.execute(FcmToken('fcm-token-abc')),
          emitsInOrder([
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'loading',
              isA<RegisterNewFirebaseRegistrationTokenLoading>(),
            ),
            isA<Left<dynamic, dynamic>>().having(
              (either) => either.value,
              'failure',
              isA<RegisterNewFirebaseRegistrationTokenFailure>(),
            ),
          ]),
        );
      },
    );

    test(
      'WHEN the same installation registers twice\n'
      'THEN both registrations carry the same install id so the platform keeps the identity',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(202, {
            'registrationId': registrationId.value,
            'expiresAt': '2026-11-17T00:00:00Z',
          }),
          data: {
            'token': 'fcm-token-old',
            'deviceClientId': storedInstallId,
            'type': 'email',
          },
        );
        await interactor.execute(FcmToken('fcm-token-old')).drain();

        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(202, {
            'registrationId': registrationId.value,
            'expiresAt': '2026-11-17T00:00:00Z',
          }),
          data: {
            'token': 'fcm-token-new',
            'deviceClientId': storedInstallId,
            'type': 'email',
          },
        );
        await interactor.execute(FcmToken('fcm-token-new')).drain();
      },
    );
  });
}
