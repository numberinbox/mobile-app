import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/web_socket_exceptions.dart';

// Browser WebSockets cannot attach an Authorization header.
Future<WebSocketChannel> connectWithAuthorization(Uri uri, String? header) =>
    Future.error(WebSocketTicketUnavailableException());

bool isLoopbackHost(String host) {
  final value = host.toLowerCase();
  if (value == 'localhost' || value == '::1' || value == '0:0:0:0:0:0:0:1') {
    return true;
  }
  final parts = value.split('.');
  return parts.length == 4 &&
      parts.first == '127' &&
      parts.every(
        (part) => RegExp(r'^\d{1,3}$').hasMatch(part) && int.parse(part) <= 255,
      );
}
