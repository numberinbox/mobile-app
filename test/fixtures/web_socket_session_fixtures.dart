import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/account/account.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_properties.dart';
import 'package:jmap_dart_client/jmap/core/capability/empty_capability.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';

import 'account_fixtures.dart';

// Stalwart v0.16.26, 2026-11-08: global push URL/support plus an empty account capability.
// Endpoint, account identifier and username are synthetic; no credentials are retained.
Session pushSession({
  bool? globalPush = true,
  WebSocketCapability? accountWebSocket,
  bool ticket = false,
  bool includeAccount = true,
  bool emptyAccountWebSocket = true,
}) => Session(
  {
    if (globalPush != null)
      CapabilityIdentifier.jmapWebSocket: WebSocketCapability(
        supportsPush: globalPush,
        url: Uri.parse('ws://localhost/jmap/ws'),
      ),
  },
  {
    if (includeAccount)
      AccountFixtures.aliceAccountId: Account(
        AccountName('alice@example.test'),
        true,
        false,
        <CapabilityIdentifier, CapabilityProperties>{
          if (accountWebSocket != null)
            CapabilityIdentifier.jmapWebSocket: accountWebSocket,
          if (emptyAccountWebSocket && accountWebSocket == null)
            CapabilityIdentifier.jmapWebSocket: EmptyCapability(),
          if (ticket)
            CapabilityIdentifier.jmapWebSocketTicket: EmptyCapability(),
        },
      ),
  },
  const <CapabilityIdentifier, AccountId>{},
  UserName('alice@example.test'),
  Uri.parse('http://localhost/jmap'),
  Uri.parse('http://localhost/download'),
  Uri.parse('http://localhost/upload'),
  Uri.parse('http://localhost/event'),
  State('fixture'),
);
