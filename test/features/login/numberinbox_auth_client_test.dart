import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late NumberInboxAuthClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);
  });

  test('start posts normalized e164 to /v1/otp/start', () async {
    adapter.onPost('/v1/otp/start', (server) {
      server.reply(200, {'ok': true});
    }, data: {'e164': '+66812345678'});

    await client.startOtp('+66 812-345-678');

    // matched by data above — no exception means the normalized body was sent
  });

  test('verify returns a session with jmap credentials', () async {
    adapter.onPost('/v1/otp/verify', (server) {
      server.reply(200, {
        'accessToken': 'jwt-token',
        'jmap': {
          'sessionUrl': 'https://jmap.numberinbox.com/.well-known/jmap',
          'username': '+66812345678@numberinbox.com',
          'credential': 'app-secret',
        }
      });
    }, data: {'e164': '+66812345678', 'code': '123456'});

    final session = await client.verifyOtp('+66812345678', '123456');

    expect(session.accessToken, 'jwt-token');
    expect(session.username, '+66812345678@numberinbox.com');
    expect(session.credential, 'app-secret');
    expect(session.sessionUrl, contains('/.well-known/jmap'));
  });

  test('otp_invalid maps to OtpInvalidException', () async {
    adapter.onPost('/v1/otp/verify', (server) {
      server.reply(401, {'error': 'otp_invalid', 'message': 'wrong code'});
    }, data: {'e164': '+66812345678', 'code': '000000'});

    expect(
      () => client.verifyOtp('+66812345678', '000000'),
      throwsA(isA<OtpInvalidException>()),
    );
  });

  test('rate_limited maps to RateLimitedException', () async {
    adapter.onPost('/v1/otp/start', (server) {
      server.reply(429, {'error': 'rate_limited', 'message': 'slow down'});
    }, data: {'e164': '+66812345678'});

    expect(
      () => client.startOtp('+66812345678'),
      throwsA(isA<RateLimitedException>()),
    );
  });

  test('invalid_e164 maps to InvalidE164Exception', () async {
    adapter.onPost('/v1/otp/start', (server) {
      server.reply(400, {'error': 'invalid_e164', 'message': 'bad number'});
    }, data: {'e164': '+66812345678'});

    expect(
      () => client.startOtp('+66812345678'),
      throwsA(isA<InvalidE164Exception>()),
    );
  });
}
