import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:fcm/model/firebase_registration_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/fcm_registration_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/state/destroy_firebase_registration_state.dart';
import 'package:tmail_ui_user/features/push_notification/domain/usecases/revoke_platform_fcm_registration_interactor.dart';

import 'revoke_platform_fcm_registration_interactor_test.mocks.dart';

@GenerateMocks([CredentialRepository])
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late MockCredentialRepository credentialRepository;
  late RevokePlatformFcmRegistrationInteractor interactor;

  final registrationId = FirebaseRegistrationId(Id('9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb'));

  setUp(() {
    dio = Dio(BaseOptions())..options.baseUrl = 'https://example.com';
    dioAdapter = DioAdapter(dio: dio);
    credentialRepository = MockCredentialRepository();
    when(credentialRepository.getAuthenticationInfoStored()).thenAnswer(
      (_) async => AuthenticationInfoCache(
        '+66841234567@numberinbox.com',
        'stalwart-password',
      ),
    );
    interactor = RevokePlatformFcmRegistrationInteractor(
      FcmRegistrationApi(dio),
      credentialRepository,
    );
  });

  test('cancelled credential lookup cannot send a late revocation', () async {
    final credentials = Completer<AuthenticationInfoCache>();
    when(credentialRepository.getAuthenticationInfoStored()).thenAnswer((_) => credentials.future);
    final token = CancelToken();
    var requests = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests++;
      handler.next(request);
    }));
    final states = interactor.execute(registrationId, cancelToken: token).toList();
    await Future<void>.delayed(Duration.zero);
    token.cancel('Session ended');
    credentials.complete(AuthenticationInfoCache('synthetic@example.test', 'synthetic'));
    await states;
    expect(requests, 0);
  });

  group('RevokePlatformFcmRegistrationInteractor.execute', () {
    test(
      'WHEN the stored registration is revoked on sign-out\n'
      'THEN deletes the registration by id with Basic auth and emits Loading then Success',
      () async {
        dioAdapter.onDelete(
          '/v1/fcm-registrations/9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
          (server) => server.reply(204, null),
          headers: {
            'Authorization':
                'Basic KzY2ODQxMjM0NTY3QG51bWJlcmluYm94LmNvbTpzdGFsd2FydC1wYXNzd29yZA==',
          },
        );

        expect(
          interactor.execute(registrationId),
          emitsInOrder([
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'loading',
              isA<DestroyFirebaseRegistrationLoading>(),
            ),
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'success',
              isA<DestroyFirebaseRegistrationSuccess>(),
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
          interactor.execute(registrationId),
          emitsInOrder([
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'loading',
              isA<DestroyFirebaseRegistrationLoading>(),
            ),
            isA<Left<dynamic, dynamic>>().having(
              (either) => either.value,
              'failure',
              isA<DestroyFirebaseRegistrationFailure>(),
            ),
          ]),
        );
      },
    );

    test(
      'WHEN the platform call fails\n'
      'THEN emits Failure so sign-out can carry on',
      () async {
        dioAdapter.onDelete(
          '/v1/fcm-registrations/9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
          (server) => server.reply(500, null),
          headers: {
            'Authorization':
                'Basic KzY2ODQxMjM0NTY3QG51bWJlcmluYm94LmNvbTpzdGFsd2FydC1wYXNzd29yZA==',
          },
        );

        expect(
          interactor.execute(registrationId),
          emitsInOrder([
            isA<Right<dynamic, dynamic>>().having(
              (either) => either.value,
              'loading',
              isA<DestroyFirebaseRegistrationLoading>(),
            ),
            isA<Left<dynamic, dynamic>>().having(
              (either) => either.value,
              'failure',
              isA<DestroyFirebaseRegistrationFailure>(),
            ),
          ]),
        );
      },
    );
  });
}
