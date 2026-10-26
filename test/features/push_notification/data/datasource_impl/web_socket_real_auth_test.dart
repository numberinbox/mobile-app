import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:model/account/password.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/push_notification/data/datasource_impl/web_socket_datasource_impl.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/web_socket_api.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';
import '../../../login/data/network/interceptors/authorization_interceptors_test.mocks.dart';

class _NoTicket implements WebSocketApi {
  @override
  Future<String?> getWebSocketTicket(
    Session session,
    AccountId accountId,
  ) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rethrow extends ExceptionThrower {
  @override
  dynamic throwException(dynamic error, dynamic stackTrace) => throw error;
}

void main() {
  test(
    'no-ticket socket uses valid Basic authorization from real interceptor',
    () async {
      HttpOverrides.global = null;
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final auth = AuthorizationInterceptors(
        dio,
        MockAuthenticationClientBase(),
        MockTokenOidcCacheManager(),
        MockAccountCacheManager(),
        MockIOSSharingManager(),
      );
      auth.setBasicAuthorization(
        UserName('audit@example.test'),
        Password('synthetic-password'),
      );
      Get.put<AuthorizationInterceptors>(auth);
      addTearDown(Get.reset);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final hasScheme =
            request.headers.value('Authorization')?.startsWith('Basic ') ??
            false;
        expect(
          request.headers.value('Authorization'),
          'Basic YXVkaXRAZXhhbXBsZS50ZXN0OnN5bnRoZXRpYy1wYXNzd29yZA==',
        );
        if (!hasScheme) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (protocols) => 'jmap',
        );
        await socket.close();
      });
      final uri = Uri.parse('ws://127.0.0.1:${server.port}/jmap/ws');
      final session = Session(
        {
          CapabilityIdentifier.jmapWebSocket: WebSocketCapability(
            supportsPush: true,
            url: uri,
          ),
        },
        const {},
        const {},
        UserName('audit@example.test'),
        Uri.parse('https://example.test/jmap'),
        Uri.parse('https://example.test/download'),
        Uri.parse('https://example.test/upload'),
        Uri.parse('https://example.test/event'),
        State('initial'),
      );
      final channel = await WebSocketDatasourceImpl(
        _NoTicket(),
        _Rethrow(),
      ).getWebSocketChannel(session, AccountId(Id('audit-account')));
      await channel.sink.close();
    },
  );
}
