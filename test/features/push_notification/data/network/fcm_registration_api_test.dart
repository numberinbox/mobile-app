import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/fcm_registration_api.dart';

const anyRequestData = Matchers.any;

void main() {
  final baseOption = BaseOptions();
  late Dio dio;
  late DioAdapter dioAdapter;
  late FcmRegistrationApi api;

  setUp(() {
    dio = Dio(baseOption)..options.baseUrl = 'https://example.com/v1';
    dioAdapter = DioAdapter(dio: dio);
    api = FcmRegistrationApi(dio);
  });

  group('FcmRegistrationApi.register', () {
    test(
      'WHEN the backend accepts the registration\n'
      'THEN posts the token, install id and email type with Basic auth and parses the reply',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(
            202,
            {
              'registrationId': '9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
              'expiresAt': '2026-11-17T00:00:00Z',
            },
          ),
          data: {
            'token': 'fcm-token-abc',
            'deviceClientId': '43b5cf0a-7c1c-4a11-b1c5-2f35e2a3a4b5',
            'type': 'email',
          },
          headers: {
            'Authorization': 'Basic bWFpbGJveEBudW1iZXJpbmJveC5jb206cGFzc3dvcmQ=',
          },
        );

        final registration = await api.register(
          token: 'fcm-token-abc',
          deviceClientId: '43b5cf0a-7c1c-4a11-b1c5-2f35e2a3a4b5',
          username: 'mailbox@numberinbox.com',
          password: 'password',
        );

        expect(registration.registrationId,
            equals('9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb'));
        expect(registration.expiresAt,
            equals(DateTime.parse('2026-11-17T00:00:00Z')));
      },
    );

    test(
      'WHEN the mailbox cannot receive push yet\n'
      'THEN throws FcmRegistrationException with the backend error code',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(409, {
            'error': 'mailbox_not_pushable',
            'message': 'mailbox is not claimed or has no linked account',
          }),
          data: anyRequestData,
        );

        final exception = await _registerFailsWith(api);

        expect(exception.code, equals('mailbox_not_pushable'));
      },
    );

    test(
      'WHEN the stored credential is rejected\n'
      'THEN throws FcmRegistrationException with the unauthorized code',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(401, {
            'error': 'unauthorized',
            'message': 'mailbox session is invalid',
          }),
          data: anyRequestData,
        );

        final exception = await _registerFailsWith(api);

        expect(exception.code, equals('unauthorized'));
      },
    );

    test(
      'WHEN the reply is not a known backend error\n'
      'THEN throws with the network_error fallback code',
      () async {
        dioAdapter.onPost(
          '/v1/fcm-registrations',
          (server) => server.reply(500, 'boom'),
          data: anyRequestData,
        );

        final exception = await _registerFailsWith(api);

        expect(exception.code, equals('network_error'));
      },
    );
  });

  group('FcmRegistrationApi.revoke', () {
    test(
      'WHEN a registration is revoked on sign-out\n'
      'THEN deletes by registration id with Basic auth and accepts 204',
      () async {
        dioAdapter.onDelete(
          '/v1/fcm-registrations/9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
          (server) => server.reply(204, null),
          headers: {
            'Authorization': 'Basic bWFpbGJveEBudW1iZXJpbmJveC5jb206cGFzc3dvcmQ=',
          },
        );

        await api.revoke(
          registrationId: '9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
          username: 'mailbox@numberinbox.com',
          password: 'password',
        );
      },
    );

    test(
      'WHEN the revoke call fails\n'
      'THEN throws FcmRegistrationException instead of crashing sign-out',
      () async {
        dioAdapter.onDelete(
          '/v1/fcm-registrations/9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
          (server) => server.reply(500, null),
          headers: {
            'Authorization': 'Basic bWFpbGJveEBudW1iZXJpbmJveC5jb206cGFzc3dvcmQ=',
          },
        );

        expect(
          () async => api.revoke(
            registrationId: '9b2d6bd2-fa01-4ec7-aad7-c976a6d3cecb',
            username: 'mailbox@numberinbox.com',
            password: 'password',
          ),
          throwsA(isA<FcmRegistrationException>()),
        );
      },
    );
  });
}

Future<FcmRegistrationException> _registerFailsWith(FcmRegistrationApi api) async {
  try {
    await api.register(
      token: 'fcm-token-abc',
      deviceClientId: '43b5cf0a-7c1c-4a11-b1c5-2f35e2a3a4b5',
      username: 'mailbox@numberinbox.com',
      password: 'password',
    );
  } on FcmRegistrationException catch (exception) {
    return exception;
  }
  fail('FcmRegistrationApi.register should have thrown FcmRegistrationException');
}
