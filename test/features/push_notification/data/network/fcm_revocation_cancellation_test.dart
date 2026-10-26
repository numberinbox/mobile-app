@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/fcm_registration_api.dart';

void main() {
  test(
    'revocation cancellation stops a real pending HTTP request without retry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<void>();
      var requests = 0;
      server.listen((request) {
        requests++;
        received.complete();
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
      addTearDown(() => dio.close(force: true));
      final token = CancelToken();
      final revoke = FcmRegistrationApi(dio).revoke(
        registrationId: 'synthetic',
        username: 'synthetic@example.test',
        password: 'synthetic',
        cancelToken: token,
      );
      final assertion = expectLater(
        revoke,
        throwsA(
          isA<FcmRegistrationException>().having(
            (e) => e.code,
            'sanitized code',
            'network_error',
          ),
        ),
      );
      await received.future.timeout(const Duration(seconds: 3));
      token.cancel('Session ended');
      await assertion;
      expect(requests, 1);
    },
  );
}
