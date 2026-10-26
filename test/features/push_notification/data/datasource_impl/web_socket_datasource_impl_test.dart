import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/push_notification/data/datasource_impl/web_socket_datasource_impl.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/web_socket_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/web_socket_exceptions.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';

import '../../../../fixtures/account_fixtures.dart';

const _basicAuthHeader = 'Basic YWxpY2U6c2VjcmV0';

Session _sessionForWebSocket(Uri webSocketUrl) => Session(
  {
    CapabilityIdentifier.jmapWebSocket: WebSocketCapability(
      supportsPush: true,
      url: webSocketUrl,
    ),
  },
  const {},
  const {},
  UserName('alice@domain.tld'),
  Uri.parse('https://domain.tld/jmap'),
  Uri.parse('https://domain.tld/download'),
  Uri.parse('https://domain.tld/upload'),
  Uri.parse('https://domain.tld/event'),
  State('initial-state'),
);

class _FakeWebSocketApi implements WebSocketApi {
  _FakeWebSocketApi({this.ticket});

  final String? ticket;

  @override
  Future<String?> getWebSocketTicket(
    Session session,
    AccountId accountId,
  ) async => ticket;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthorizationInterceptors implements AuthorizationInterceptors {
  _FakeAuthorizationInterceptors(this.header);

  final String? header;
  int headerReads = 0;

  @override
  String? get basicAuthorizationHeader {
    headerReads++;
    return header;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RethrowingExceptionThrower extends ExceptionThrower {
  @override
  dynamic throwException(dynamic error, dynamic stackTrace) => throw error;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthorizationInterceptors authorizationInterceptors;

  // flutter_test installs an HttpClient mock that answers every request with
  // 400; these tests need real loopback sockets to exercise the TLS handshake.
  setUpAll(() => HttpOverrides.global = null);

  setUp(() {
    authorizationInterceptors = _FakeAuthorizationInterceptors(_basicAuthHeader);
    Get.put<AuthorizationInterceptors>(authorizationInterceptors, permanent: true);
  });

  tearDown(Get.reset);

  WebSocketDatasourceImpl datasourceWith({String? ticket}) =>
      WebSocketDatasourceImpl(
        _FakeWebSocketApi(ticket: ticket),
        _RethrowingExceptionThrower(),
      );

  test('a server that never upgrades cannot leave socket establishment pending', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<void>();
    server.listen((request) { received.complete(); });
    final elapsed = Stopwatch()..start();
    final connection = datasourceWith().getWebSocketChannel(
      _sessionForWebSocket(Uri.parse('ws://127.0.0.1:${server.port}/socket')),
      AccountFixtures.aliceAccountId,
    );
    final assertion = expectLater(connection, throwsA(anyOf(
      isA<TimeoutException>(), isA<WebSocketClosedException>(),
    )));
    await received.future.timeout(const Duration(seconds: 3));
    await assertion;
    expect(elapsed.elapsed, greaterThanOrEqualTo(const Duration(seconds: 9)));
    expect(elapsed.elapsed, lessThan(const Duration(seconds: 15)));
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('failed ticket handshakes expose no ticket in the propagated error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.close();
    });
    Object? failure;
    try {
      await datasourceWith(ticket: 'sentinel-secret-ticket').getWebSocketChannel(
        _sessionForWebSocket(Uri.parse('ws://127.0.0.1:${server.port}/socket')),
        AccountFixtures.aliceAccountId,
      );
    } catch (error) { failure = error; }
    expect(failure, isA<WebSocketClosedException>());
    expect(failure.toString(), isNot(contains('sentinel-secret-ticket')));
  });

  group('WebSocketDatasourceImpl::TLS verification', () {
    test(
      'WHEN the server presents a self-signed certificate that is not trusted\n'
      'THEN the connection is refused\n'
      'AND the mailbox Basic credentials never reach the server',
      () async {
        final server = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4,
          0,
          _selfSignedServerContext(),
        );
        final requests = <HttpRequest>[];
        server.listen((request) {
          requests.add(request);
          // Deliberately never answer: a verified client aborts during the
          // TLS handshake, so no request must arrive here.
        });
        addTearDown(() => server.close(force: true));

        final datasource = datasourceWith();
        await expectLater(
          datasource.getWebSocketChannel(
            _sessionForWebSocket(
              Uri.parse('wss://127.0.0.1:${server.port}/jmap/ws'),
            ),
            AccountFixtures.aliceAccountId,
          ),
          throwsA(anything),
        );

        expect(
          requests,
          isEmpty,
          reason: 'an untrusted certificate must abort before the '
              'Authorization header is written to the socket',
        );
      },
    );

    test(
      'WHEN the server presents a self-signed certificate on the ticket path\n'
      'THEN the connection is refused and no ticket is leaked',
      () async {
        final server = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4,
          0,
          _selfSignedServerContext(),
        );
        final requests = <HttpRequest>[];
        server.listen((request) => requests.add(request));
        addTearDown(() => server.close(force: true));

        final datasource = datasourceWith(ticket: 'web-socket-ticket');
        await expectLater(
          datasource.getWebSocketChannel(
            _sessionForWebSocket(
              Uri.parse('wss://127.0.0.1:${server.port}/jmap/ws'),
            ),
            AccountFixtures.aliceAccountId,
          ),
          throwsA(anything),
        );

        expect(requests, isEmpty);
        expect(
          authorizationInterceptors.headerReads,
          0,
          reason: 'the ticket path must not even read the Basic credentials',
        );
      },
    );
  });

  group('WebSocketDatasourceImpl::plaintext WebSocket scheme', () {
    test(
      'WHEN the capability advertises a non-loopback ws:// URL\n'
      'THEN the connection is rejected before any credential is sent',
      () async {
        final datasource = datasourceWith();

        await expectLater(
          datasource.getWebSocketChannel(
            _sessionForWebSocket(Uri.parse('ws://mail.example.com/jmap/ws')),
            AccountFixtures.aliceAccountId,
          ),
          throwsA(isA<WebSocketInsecureSchemeException>()),
        );
        expect(authorizationInterceptors.headerReads, 0);
      },
    );

    test(
      'WHEN the capability advertises a loopback ws:// URL and no ticket exists\n'
      'THEN the connection is allowed (test/local server capability)\n'
      'AND the Basic Authorization header is sent',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final authorizationHeaders = <String?>[];
        server.listen((request) async {
          authorizationHeaders.add(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          final socket = await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (protocols) =>
                protocols.contains('jmap') ? 'jmap' : null,
          );
          await socket.close();
        });
        addTearDown(() => server.close(force: true));

        final datasource = datasourceWith();
        final channel = await datasource.getWebSocketChannel(
          _sessionForWebSocket(
            Uri.parse('ws://127.0.0.1:${server.port}/jmap/ws'),
          ),
          AccountFixtures.aliceAccountId,
        );
        addTearDown(() => channel.sink.close());

        await _waitUntil(() => authorizationHeaders.isNotEmpty);
        expect(authorizationHeaders.single, _basicAuthHeader);
      },
    );
  });
}

SecurityContext _selfSignedServerContext() => SecurityContext()
  ..useCertificateChain('test/fixtures/tls/cert.pem')
  ..usePrivateKey('test/fixtures/tls/key.pem');

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for the server handshake');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
