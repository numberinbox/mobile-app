import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import '../../integration_test/utils/backend_reset_client.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late BackendResetRequest request;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9999'));
    adapter = DioAdapter(dio: dio);
    request = BackendResetRequest(dio);
  });

  tearDown(() => dio.close(force: true));

  test('does nothing when reset URL is unset', () async {
    await request.reset('');
  });

  test('accepts only HTTP 200', () async {
    adapter.onPost(RegExp(r'.*/reset$'), (server) => server.reply(200, 'ok'));
    await request.reset('http://127.0.0.1:9999');
  });

  test('fails on non-200 without exposing endpoint or response body', () async {
    adapter.onPost(
      RegExp(r'.*/reset$'),
      (server) => server.reply(503, 'SENTINEL_SECRET'),
    );

    await expectLater(
      request.reset('http://127.0.0.1:9999'),
      throwsA(
        isA<BackendResetException>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('reset'),
            isNot(contains('SENTINEL_SECRET')),
            isNot(contains('127.0.0.1')),
          ),
        ),
      ),
    );
  });

  test('propagates connection failure as a sanitized error', () async {
    adapter.onPost(
      RegExp(r'.*/reset$'),
      (server) => server.throws(
        500,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/reset'),
          reason: 'SENTINEL_SECRET',
        ),
      ),
    );

    await expectLater(
      request.reset('http://127.0.0.1:9999'),
      throwsA(
        isA<BackendResetException>().having(
          (error) => error.toString(),
          'message',
          isNot(contains('SENTINEL_SECRET')),
        ),
      ),
    );
  });

  test('propagates timeout as a sanitized error', () async {
    adapter.onPost(
      RegExp(r'.*/reset$'),
      (server) => server.throws(
        500,
        DioException.connectionTimeout(
          timeout: const Duration(milliseconds: 1),
          requestOptions: RequestOptions(path: '/reset'),
        ),
      ),
    );

    await expectLater(
      request.reset('http://127.0.0.1:9999'),
      throwsA(isA<BackendResetException>()),
    );
  });
}
