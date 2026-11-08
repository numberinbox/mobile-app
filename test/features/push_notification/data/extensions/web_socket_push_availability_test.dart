import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:tmail_ui_user/features/push_notification/data/extensions/web_socket_push_availability_extension.dart';

import '../../../../fixtures/account_fixtures.dart';
import '../../../../fixtures/web_socket_session_fixtures.dart';

void main() {
  test('captured Stalwart wire shape survives the real session decoder', () {
    final accountId = AccountFixtures.aliceAccountId;
    final session = Session.fromJson({
      'capabilities': {
        'urn:ietf:params:jmap:websocket': {
          'url': 'ws://localhost/jmap/ws',
          'supportsPush': true,
        },
      },
      'accounts': {
        accountId.id.value: {
          'name': 'alice@example.test',
          'isPersonal': true,
          'isReadOnly': false,
          'accountCapabilities': {'urn:ietf:params:jmap:websocket': {}},
        },
      },
      'primaryAccounts': <String, dynamic>{},
      'username': 'alice@example.test',
      'apiUrl': 'http://localhost/jmap',
      'downloadUrl': 'http://localhost/download',
      'uploadUrl': 'http://localhost/upload',
      'eventSourceUrl': 'http://localhost/event',
      'state': 'fixture',
    });
    expect(
      session.canStartWebSocketPush(
        accountId,
        hasBasicCredentials: true,
        isWeb: false,
      ),
      isTrue,
    );
  });

  final accountSocket = WebSocketCapability(
    supportsPush: true,
    url: Uri.parse('ws://localhost/jmap/ws'),
  );
  final cases = [
    (
      name: 'global-only push without any account websocket entry',
      session: pushSession(emptyAccountWebSocket: false),
      basic: true,
      web: false,
      allowed: true,
    ),
    (
      name:
          'Stalwart global push with empty account capability on native Basic',
      session: pushSession(),
      basic: true,
      web: false,
      allowed: true,
    ),
    (
      name: 'account push without ticket on native Basic',
      session: pushSession(globalPush: null, accountWebSocket: accountSocket),
      basic: true,
      web: false,
      allowed: true,
    ),
    (
      name: 'Twake ticket push with OIDC',
      session: pushSession(accountWebSocket: accountSocket, ticket: true),
      basic: false,
      web: false,
      allowed: true,
    ),
    (
      name: 'ticket push with Basic on web',
      session: pushSession(accountWebSocket: accountSocket, ticket: true),
      basic: true,
      web: true,
      allowed: true,
    ),
    (
      name: 'no ticket and OIDC on native',
      session: pushSession(),
      basic: false,
      web: false,
      allowed: false,
    ),
    (
      name: 'no ticket and Basic on web',
      session: pushSession(),
      basic: true,
      web: true,
      allowed: false,
    ),
    (
      name: 'push disabled with ticket',
      session: pushSession(globalPush: false, ticket: true),
      basic: true,
      web: false,
      allowed: false,
    ),
    (
      name: 'no websocket capability',
      session: pushSession(globalPush: null, ticket: true),
      basic: true,
      web: false,
      allowed: false,
    ),
    (
      name: 'unknown account despite global capability',
      session: pushSession(includeAccount: false),
      basic: true,
      web: false,
      allowed: false,
    ),
    (
      name: 'account false takes precedence over global true',
      session: pushSession(
        accountWebSocket: WebSocketCapability(supportsPush: false),
      ),
      basic: true,
      web: false,
      allowed: false,
    ),
    (
      name: 'account true takes precedence over global false',
      session: pushSession(globalPush: false, accountWebSocket: accountSocket),
      basic: true,
      web: false,
      allowed: true,
    ),
    (
      name: 'empty account capability falls back to global',
      session: pushSession(emptyAccountWebSocket: true),
      basic: true,
      web: false,
      allowed: true,
    ),
    (
      name: 'account missing supportsPush falls back to global',
      session: pushSession(accountWebSocket: WebSocketCapability()),
      basic: true,
      web: false,
      allowed: true,
    ),
    (
      name: 'unknown account with claimed ticket cannot start',
      session: pushSession(includeAccount: false, ticket: true),
      basic: false,
      web: false,
      allowed: false,
    ),
  ];
  for (final c in cases) {
    test(c.name, () {
      expect(
        c.session.canStartWebSocketPush(
          AccountFixtures.aliceAccountId,
          hasBasicCredentials: c.basic,
          isWeb: c.web,
        ),
        c.allowed,
      );
    });
  }
}
