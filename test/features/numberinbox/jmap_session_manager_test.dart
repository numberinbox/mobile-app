import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/jmap_session_manager.dart';

/// The OTP response carries the JMAP URL the credentials are valid for. If that
/// URL is used unchecked, whoever answers `/v1/otp/verify` decides where the
/// user's Basic-auth credentials are sent, so the origin has to be pinned to
/// the configured JMAP host.
void main() {
  const sentinelPassword = 'CREDENTIAL-MARKER-abc123';
  const sentinelHost = 'attacker-jmap.example';

  OtpSession sessionWithUrl(String sessionUrl) => OtpSession(
        accessToken: 'jwt',
        username: '+66812345678@numberinbox.com',
        sessionUrl: sessionUrl,
        credential: sentinelPassword,
      );

  /// Asserts that [sessionUrl] is refused, and that the refusal says nothing
  /// about the URL or the credentials that came with it.
  void expectRefused(JmapSessionManager manager, String sessionUrl) {
    Object? thrown;
    try {
      manager.baseUrlFromSession(sessionWithUrl(sessionUrl));
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isA<UntrustedJmapSessionUrlException>(),
        reason: '"$sessionUrl" must not yield a usable base URL');
    // An empty expected value would match every string.
    final echoed = sessionUrl.isEmpty ? null : sessionUrl;
    expect(
      thrown.toString(),
      isNot(contains(echoed)),
      reason: 'the rejection must not echo the untrusted URL',
    );
    expect(
      thrown.toString(),
      isNot(contains(sentinelPassword)),
      reason: 'the rejection must not echo credentials',
    );
    expect(
      thrown.toString(),
      isNot(contains(sentinelHost)),
      reason: 'the rejection must not name the rejected host',
    );
  }

  group('configured production origin', () {
    final manager = JmapSessionManager();

    test('accepts the configured JMAP host', () {
      final baseUrl = manager.baseUrlFromSession(
        sessionWithUrl('https://jmap.numberinbox.com/.well-known/jmap'),
      );

      expect(baseUrl.toString(), 'https://jmap.numberinbox.com');
    });

    test('accepts a bare origin with an explicit default port', () {
      final baseUrl = manager.baseUrlFromSession(
        sessionWithUrl('https://jmap.numberinbox.com:443/'),
      );

      expect(baseUrl.host, 'jmap.numberinbox.com');
      expect(baseUrl.scheme, 'https');
    });

    test('drops query and fragment from an accepted origin', () {
      final baseUrl = manager.baseUrlFromSession(
        sessionWithUrl('https://jmap.numberinbox.com/jmap?token=leak#frag'),
      );

      expect(baseUrl.toString(), 'https://jmap.numberinbox.com');
    });

    test('accepts a differently cased host', () {
      final baseUrl = manager.baseUrlFromSession(
        sessionWithUrl('https://JMAP.NumberInbox.com/.well-known/jmap'),
      );

      expect(baseUrl.host, 'jmap.numberinbox.com');
    });

    test('rejects another host', () {
      expectRefused(manager, 'https://$sentinelHost/.well-known/jmap');
    });

    test('rejects a subdomain of the configured host', () {
      expectRefused(manager, 'https://evil.jmap.numberinbox.com/.well-known/jmap');
    });

    test('rejects a host that merely ends with the configured host', () {
      expectRefused(manager, 'https://jmap.numberinbox.com.attacker.example/x');
    });

    test('rejects a userinfo trick that moves the real host to userinfo', () {
      expectRefused(
        manager,
        'https://jmap.numberinbox.com@$sentinelHost/.well-known/jmap',
      );
    });

    test('rejects plain http', () {
      expectRefused(manager, 'http://jmap.numberinbox.com/.well-known/jmap');
    });

    test('rejects a non-web scheme', () {
      expectRefused(
        manager,
        'ftp://jmap.numberinbox.com/.well-known/jmap',
      );
    });

    test('rejects an alternate port', () {
      expectRefused(manager, 'https://jmap.numberinbox.com:8443/.well-known/jmap');
    });

    test('rejects a host-less URL', () {
      expectRefused(manager, 'https:///.well-known/jmap');
    });

    test('rejects a malformed URL', () {
      expectRefused(manager, 'not a url at all');
    });

    test('rejects an empty URL', () {
      expectRefused(manager, '');
    });

    test('rejects a scheme-relative URL', () {
      expectRefused(manager, '//jmap.numberinbox.com/.well-known/jmap');
    });
  });

  group('injected local development origin', () {
    // Local development points the manager at a plain-http Stalwart instance.
    // The response must still match that origin exactly.
    final manager = JmapSessionManager(baseUrl: 'http://localhost:8080');

    test('accepts the injected http origin', () {
      final baseUrl = manager.baseUrlFromSession(
        sessionWithUrl('http://localhost:8080/.well-known/jmap'),
      );

      expect(baseUrl.toString(), 'http://localhost:8080');
    });

    test('rejects http downgrade of an injected https origin', () {
      final https = JmapSessionManager(baseUrl: 'https://jmap.staging.example');

      Object? thrown;
      try {
        https.baseUrlFromSession(sessionWithUrl('http://jmap.staging.example/x'));
      } catch (error) {
        thrown = error;
      }
      expect(thrown, isA<UntrustedJmapSessionUrlException>());
    });

    test('rejects another local port', () {
      expectRefused(manager, 'http://localhost:9090/.well-known/jmap');
    });

    test('rejects another local host', () {
      expectRefused(manager, 'http://127.0.0.1:8080/.well-known/jmap');
    });
  });

  // The origin checks above decide WHERE the credential may be sent. These
  // tests cover what is actually sent there on every subsequent call: the
  // private Android smoke test signs in with an OTP and then reuses that same
  // stored session for inbox reads and mail sends, so a regression in the
  // header or the endpoint shape would only surface as a broken mail run.
  group('credential reuse against the session endpoint', () {
    final manager = JmapSessionManager();

    test('decodes to the username and credential from the OTP response', () {
      final decoded = manager.decodeBasicAuth(
        sessionWithUrl('https://jmap.numberinbox.com/.well-known/jmap'),
      );
      expect(decoded['username'], '+66812345678@numberinbox.com');
      expect(decoded['password'], sentinelPassword);
    });

    test('builds Basic auth as username:credential, not the access token', () {
      final header = manager.buildBasicAuthHeader(
        sessionWithUrl('https://jmap.numberinbox.com/.well-known/jmap'),
      );
      // "jwt" is the API access token and must never become the JMAP password.
      final encoded = header.substring('Basic '.length);
      final decoded = utf8.decode(base64.decode(encoded));

      expect(header, startsWith('Basic '));
      expect(decoded, '+66812345678@numberinbox.com:$sentinelPassword');
      expect(decoded, isNot(contains('jwt')));
    });

    test('targets the JMAP session endpoint under the configured origin', () {
      expect(manager.sessionEndpoint, 'https://jmap.numberinbox.com/jmap');
    });

    test('an injected local origin redirects the endpoint, not the default', () {
      final local = JmapSessionManager(baseUrl: 'http://10.0.2.2:8080');
      expect(local.sessionEndpoint, 'http://10.0.2.2:8080/jmap');
      expect(
        local.baseUrlFromSession(
          sessionWithUrl('http://10.0.2.2:8080/.well-known/jmap'),
        ).toString(),
        'http://10.0.2.2:8080',
      );
    });

    test('only a 401 counts as an unusable credential', () {
      expect(manager.isCredentialError(401, null), isTrue);
      expect(manager.isCredentialError(400, 'invalid_e164'), isFalse);
      expect(manager.isCredentialError(500, null), isFalse);
    });
  });
}