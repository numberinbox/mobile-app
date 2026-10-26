
import 'dart:async';

import 'package:core/presentation/extensions/uri_extension.dart';
import 'package:core/utils/app_logger.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/websocket_capability.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:model/extensions/session_extension.dart';
import 'package:tmail_ui_user/features/login/data/network/interceptors/authorization_interceptors.dart';
import 'package:tmail_ui_user/features/push_notification/data/datasource/web_socket_datasource.dart';
import 'package:tmail_ui_user/features/push_notification/data/network/web_socket_api.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/web_socket_exceptions.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'web_socket_connector.dart'
    if (dart.library.io) 'web_socket_connector_io.dart' as connector;

class WebSocketDatasourceImpl implements WebSocketDatasource {
  final WebSocketApi _webSocketApi;
  final ExceptionThrower _exceptionThrower;
  
  const WebSocketDatasourceImpl(this._webSocketApi, this._exceptionThrower);

  @override
  Future<WebSocketChannel> getWebSocketChannel(Session session, AccountId accountId) {
    return Future.sync(() async {
      _verifyWebSocketCapabilities(session, accountId);
      final webSocketTicket = await _webSocketApi.getWebSocketTicket(session, accountId);
      final webSocketUri = _resolveSecureWebSocketUri(session, accountId);

      WebSocketChannel? channel;
      var expired = false;
      Future<WebSocketChannel> connect() async {
        if (webSocketTicket != null) {
          channel = WebSocketChannel.connect(
            webSocketUri.replace(queryParameters: {
              ...webSocketUri.queryParameters, 'ticket': webSocketTicket,
            }),
            protocols: ['jmap'],
          );
        } else {
          channel = await connector.connectWithAuthorization(webSocketUri, _getBasicAuthHeader());
        }
        if (expired) {
          unawaited(channel!.sink.close());
          throw TimeoutException('WebSocket connection expired');
        }
        await channel!.ready;
        return channel!;
      }
      final webSocketChannel = await connect().catchError((Object error) {
        if (error is WebSocketTicketUnavailableException) throw error;
        // Handshake errors may embed a ticket-bearing URL.
        throw WebSocketClosedException('Connection failed');
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          expired = true;
          final pending = channel;
          if (pending != null) unawaited(pending.sink.close());
          throw TimeoutException('WebSocket connection expired');
        },
      );

      return webSocketChannel;
    }).catchError(_exceptionThrower.throwException);
  }

  String? _getBasicAuthHeader() {
    try {
      final authInterceptor = Get.find<AuthorizationInterceptors>();
      return authInterceptor.basicAuthorizationHeader;
    } catch (e) {
      logWarning('WebSocket authorization unavailable: ${e.runtimeType}');
      return null;
    }
  }

  Uri _resolveSecureWebSocketUri(Session session, AccountId accountId) {
    final webSocketUri = _getWebSocketUri(session, accountId).ensureWebSocketUri();
    if (webSocketUri.scheme == 'ws' && !connector.isLoopbackHost(webSocketUri.host)) {
      throw WebSocketInsecureSchemeException(
        'Refusing plaintext WebSocket connection to ${webSocketUri.host}',
      );
    }
    return webSocketUri;
  }

  WebSocketCapability? _findWebSocketCapability(Session session, AccountId accountId) {
    var fromAccount = session.getCapabilityProperties<WebSocketCapability>(
      accountId,
      CapabilityIdentifier.jmapWebSocket);
    if (fromAccount?.supportsPush != null) return fromAccount;
    final fromGlobal = session.capabilities[CapabilityIdentifier.jmapWebSocket];
    if (fromGlobal is WebSocketCapability && fromGlobal.supportsPush == true) {
      return fromGlobal;
    }
    return fromAccount;
  }

  void _verifyWebSocketCapabilities(Session session, AccountId accountId) {
    final wsCap = _findWebSocketCapability(session, accountId);
    if (wsCap?.supportsPush != true) {
      throw WebSocketPushNotSupportedException();
    }
  }

  Uri _getWebSocketUri(Session session, AccountId accountId) {
    final webSocketCapability = _findWebSocketCapability(session, accountId);
    if (webSocketCapability?.supportsPush != true) {
      throw WebSocketPushNotSupportedException();
    }
    final webSocketUri = webSocketCapability?.url;
    if (webSocketUri == null) throw WebSocketUriUnavailableException();

    return webSocketUri;
  }
}