@TestOn('chrome')
library;

import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:tmail_ui_user/features/push_notification/data/datasource_impl/web_socket_datasource_impl.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/web_socket_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/web_socket_exceptions.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/main/bindings/network/network_bindings.dart';

// Opt in with --dart-define=NETWORK_FIXTURE_URL=http://127.0.0.1:<port>.
// The local fixture must return 200 and allow the test browser's CORS origin.
class _TicketApi implements WebSocketApi {
  _TicketApi(this.ticket);
  final String? ticket;
  @override
  Future<String?> getWebSocketTicket(
    Session session,
    AccountId accountId,
  ) async => ticket;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rethrow extends ExceptionThrower {
  @override
  dynamic throwException(dynamic error, dynamic stackTrace) => throw error;
}

void main() {
  const fixture = String.fromEnvironment('NETWORK_FIXTURE_URL');
  for (final debug in [true, false]) {
    test(
      '${debug ? 'debug' : 'production'} browser HTTP uses the platform adapter',
      () async {
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        addTearDown(() => dio.close(force: true));
        if (debug) {
          NetworkBindings.configureDebugDio(dio);
        } else {
          NetworkBindings.configureProductionDio(dio);
        }
        final result = await dio.get<String>('$fixture/healthy');
        expect(result.statusCode, 200);
        expect(result.data, 'ok');
      },
      skip: fixture.isEmpty
          ? 'Requires the opt-in local network fixture'
          : false,
    );
  }
  Session session() => Session(
    {
      CapabilityIdentifier.jmapWebSocket: WebSocketCapability(
        supportsPush: true,
        url: Uri.parse(fixture).replace(scheme: 'ws', path: '/socket'),
      ),
    },
    const {},
    const {},
    UserName('synthetic@example.test'),
    Uri.parse('$fixture/jmap'),
    Uri.parse('$fixture/download'),
    Uri.parse('$fixture/upload'),
    Uri.parse('$fixture/event'),
    State('initial'),
  );

  test(
    'browser connects using a ticket',
    () async {
      final channel = await WebSocketDatasourceImpl(
        _TicketApi('synthetic-ticket'),
        _Rethrow(),
      ).getWebSocketChannel(session(), AccountId(Id('synthetic-account')));
      await channel.sink.close();
    },
    skip: fixture.isEmpty ? 'Requires local network fixture' : false,
  );

  test(
    'browser without a ticket fails promptly without native APIs',
    () async {
      await expectLater(
        WebSocketDatasourceImpl(
          _TicketApi(null),
          _Rethrow(),
        ).getWebSocketChannel(session(), AccountId(Id('synthetic-account'))),
        throwsA(isA<WebSocketTicketUnavailableException>()),
      );
    },
    skip: fixture.isEmpty ? 'Requires local network fixture' : false,
  );
}
