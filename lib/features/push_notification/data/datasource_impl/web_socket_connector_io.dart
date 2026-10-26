import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

Future<WebSocketChannel> connectWithAuthorization(
  Uri uri,
  String? header,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final socket =
        await WebSocket.connect(
          uri.toString(),
          headers: header == null ? null : {'Authorization': header},
          protocols: ['jmap'],
          customClient: client,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            client.close(force: true);
            throw TimeoutException('WebSocket connection expired');
          },
        );
    return IOWebSocketChannel(socket);
  } finally {
    client.close();
  }
}

bool isLoopbackHost(String host) =>
    host.toLowerCase() == 'localhost' ||
    (InternetAddress.tryParse(host)?.isLoopback ?? false);
