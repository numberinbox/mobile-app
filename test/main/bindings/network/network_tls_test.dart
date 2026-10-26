@TestOn('vm')
library;

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/main/bindings/network/network_bindings.dart';

void main() {
  for (final debug in [true, false]) {
    test(
      '${debug ? 'debug' : 'production'} rejects an untrusted TLS certificate',
      () async {
        final directory = await Directory.systemTemp.createTemp('ni-tls-');
        addTearDown(() => directory.delete(recursive: true));
        final cert = '${directory.path}/cert.pem';
        final key = '${directory.path}/key.pem';
        final ca = '${directory.path}/ca.pem';
        final caKey = '${directory.path}/ca-key.pem';
        final csr = '${directory.path}/server.csr';
        final extensions = '${directory.path}/server.ext';
        await File(extensions).writeAsString(
          'basicConstraints=critical,CA:FALSE\n'
          'keyUsage=critical,digitalSignature,keyEncipherment\n'
          'extendedKeyUsage=serverAuth\n'
          'subjectAltName=DNS:localhost,IP:127.0.0.1\n',
        );
        Future<void> openssl(List<String> args) async {
          final result = await Process.run('openssl', args);
          expect(
            result.exitCode,
            0,
            reason: 'Unable to generate disposable TLS fixture',
          );
        }

        await openssl([
          'req',
          '-x509',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-keyout',
          caKey,
          '-out',
          ca,
          '-days',
          '1',
          '-subj',
          '/CN=Test Root',
          '-addext',
          'basicConstraints=critical,CA:TRUE',
          '-addext',
          'keyUsage=critical,keyCertSign,cRLSign',
        ]);
        await openssl([
          'req',
          '-new',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-keyout',
          key,
          '-out',
          csr,
          '-subj',
          '/CN=localhost',
        ]);
        await openssl([
          'x509',
          '-req',
          '-in',
          csr,
          '-CA',
          ca,
          '-CAkey',
          caKey,
          '-CAcreateserial',
          '-out',
          cert,
          '-days',
          '1',
          '-extfile',
          extensions,
        ]);
        final context = SecurityContext()
          ..useCertificateChain(cert)
          ..usePrivateKey(key);
        final server = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4,
          0,
          context,
        );
        addTearDown(() => server.close(force: true));
        server.listen((request) {
          request.response.write('ok');
          request.response.close();
        }, onError: (Object _) {});
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
        await expectLater(
          dio.get<String>('https://localhost:${server.port}'),
          throwsA(
            isA<DioException>().having(
              (error) => error.error,
              'TLS handshake',
              isA<HandshakeException>(),
            ),
          ),
        );
        // A trusted root still works: configuration must preserve the runtime's
        // adapter and its trust store rather than replacing it with trust-all.
        final trusted = SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates(ca);
        final trustedDio = Dio()
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => HttpClient(context: trusted),
          );
        addTearDown(() => trustedDio.close(force: true));
        if (debug) {
          NetworkBindings.configureDebugDio(trustedDio);
        } else {
          NetworkBindings.configureProductionDio(trustedDio);
        }
        expect(
          (await trustedDio.get<String>(
            'https://localhost:${server.port}',
          )).data,
          'ok',
        );
      },
    );
  }
}
