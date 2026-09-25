import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_client.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AccountDeletionClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.numberinbox.test'));
    adapter = DioAdapter(dio: dio);
    client = AccountDeletionClient(dio);
  });

  test('submits the existing mailbox credential without requesting an OTP', () async {
    final basic = base64Encode(utf8.encode(
      '+66812345678@numberinbox.test:app-secret',
    ));
    adapter.onPost('/v1/account-deletions', (server) {
      server.reply(202, {
        'requestId': '7f4e7149-7e41-40f3-9fc1-94798e9487eb',
        'status': 'deleting',
        'statusToken': 'status-secret',
      });
    }, data: {'confirmE164': '+66812345678'}, headers: {
      'Authorization': 'Basic $basic',
      'Idempotency-Key': 'request-1',
    });

    final result = await client.request(
      confirmE164: '+66812345678',
      username: '+66812345678@numberinbox.test',
      password: 'app-secret',
      idempotencyKey: 'request-1',
    );

    expect(result.requestId, '7f4e7149-7e41-40f3-9fc1-94798e9487eb');
    expect(result.statusToken, 'status-secret');
  });

  test('reads deletion status with the restricted status token', () async {
    adapter.onGet('/v1/account-deletions/request-1', (server) {
      server.reply(200, {'status': 'completed'});
    }, headers: {'Authorization': 'Bearer status-secret'});

    expect(await client.status('request-1', 'status-secret'), 'completed');
  });
}
