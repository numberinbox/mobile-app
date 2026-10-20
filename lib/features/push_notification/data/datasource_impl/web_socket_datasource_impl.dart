
import 'dart:async';
import 'dart:io';

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
import 'package:web_socket_channel/io.dart';

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

      WebSocketChannel webSocketChannel;
      if (webSocketTicket != null) {
        webSocketChannel = WebSocketChannel.connect(
          Uri.parse('${webSocketUri.toString()}?ticket=$webSocketTicket'),
          protocols: ["jmap"],
        );
      } else {
        final authHeader = _getBasicAuthHeader();
        final ws = await WebSocket.connect(
          webSocketUri.toString(),
          headers: authHeader != null ? {'Authorization': authHeader} : null,
          protocols: ["jmap"],
        );
        webSocketChannel = IOWebSocketChannel(ws);
      }

      await webSocketChannel.ready;

      return webSocketChannel;
    }).catchError(_exceptionThrower.throwException);
  }

  String? _getBasicAuthHeader() {
    try {
      final authInterceptor = Get.find<AuthorizationInterceptors>();
      return authInterceptor.basicAuthorizationHeader;
    } catch (e) {
      logWarning('WebSocketDatasourceImpl::_getBasicAuthHeader: $e');
      return null;
    }
  }

  Uri _resolveSecureWebSocketUri(Session session, AccountId accountId) {
    final webSocketUri = _getWebSocketUri(session, accountId).ensureWebSocketUri();
    if (webSocketUri.scheme == 'ws' && !_isLoopbackHost(webSocketUri.host)) {
      throw WebSocketInsecureSchemeException(
        'Refusing plaintext WebSocket connection to ${webSocketUri.host}',
      );
    }
    return webSocketUri;
  }

  bool _isLoopbackHost(String host) {
    final normalizedHost = host.toLowerCase();
    if (normalizedHost == 'localhost') return true;
    return InternetAddress.tryParse(normalizedHost)?.isLoopback ?? false;
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
    log('WebSocketDatasourceImpl::_getWebSocketUri: webSocketCapability = ${webSocketCapability?.toJson()}');
    final webSocketUri = webSocketCapability?.url;
    if (webSocketUri == null) throw WebSocketUriUnavailableException();

    return webSocketUri;
  }
}