import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/extensions/session_extension.dart';
import 'package:tmail_ui_user/main/error/capability_validator.dart';

extension WebSocketPushAvailabilityExtension on Session {
  bool canStartWebSocketPush(
    AccountId accountId, {
    required bool hasBasicCredentials,
    required bool isWeb,
  }) {
    if (!accounts.containsKey(accountId)) return false;
    var capability = getCapabilityProperties<WebSocketCapability>(
      accountId,
      CapabilityIdentifier.jmapWebSocket,
    );
    // Match datasource precedence: an explicit account false wins; absent
    // push support (including Stalwart's empty account entry) uses global.
    if (capability?.supportsPush == null) {
      final global = capabilities[CapabilityIdentifier.jmapWebSocket];
      if (global is WebSocketCapability) capability = global;
    }
    if (capability?.supportsPush != true) return false;
    return CapabilityIdentifier.jmapWebSocketTicket.isSupported(
          this,
          accountId,
        ) ||
        (!isWeb && hasBasicCredentials);
  }
}
