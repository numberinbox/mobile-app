import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/jmap_session_manager.dart';

void main() {
  group('JmapSessionManager', () {
    test('defaults to https://jmap.numberinbox.com when no env override', () {
      final mgr = JmapSessionManager();
      expect(mgr.baseUrl, 'https://jmap.numberinbox.com');
    });

    test('accepts env-overridden base URL', () {
      final mgr = JmapSessionManager(baseUrl: 'http://localhost:8080');
      expect(mgr.baseUrl, 'http://localhost:8080');
    });

    test('builds correct session endpoint from baseUrl', () {
      final mgr = JmapSessionManager();
      expect(mgr.sessionEndpoint, 'https://jmap.numberinbox.com/jmap');
    });

    test('sessionEndpoint uses overridden baseUrl', () {
      final mgr = JmapSessionManager(baseUrl: 'http://localhost:8080');
      expect(mgr.sessionEndpoint, 'http://localhost:8080/jmap');
    });

    test('builds correct authorization header from OtpSession', () {
      final mgr = JmapSessionManager();
      final session = OtpSession(
        accessToken: 'jwt-token',
        username: '+66812345678@numberinbox.com',
        sessionUrl: 'https://jmap.numberinbox.com/.well-known/jmap',
        credential: 'app-secret',
      );
      final header = mgr.buildBasicAuthHeader(session);
      expect(header, startsWith('Basic '));
      expect(header, isNotEmpty);
    });

    test('credential mapping uses credential (not accessToken) as password', () {
      final mgr = JmapSessionManager();
      final session = OtpSession(
        accessToken: 'jwt-token-should-not-be-used',
        username: '+66812345678@numberinbox.com',
        sessionUrl: 'https://jmap.numberinbox.com/.well-known/jmap',
        credential: 'the-real-app-secret',
      );
      final decoded = mgr.decodeBasicAuth(session);
      expect(decoded['username'], '+66812345678@numberinbox.com');
      expect(decoded['password'], 'the-real-app-secret');
      expect(decoded['password'], isNot('jwt-token-should-not-be-used'));
    });

    test('sessionUrl from OtpSession is used as base URL', () {
      final mgr = JmapSessionManager();
      final session = OtpSession(
        accessToken: 'jwt',
        username: '+66812345678@numberinbox.com',
        sessionUrl: 'https://jmap.numberinbox.com/.well-known/jmap',
        credential: 'secret',
      );
      final baseUrl = mgr.baseUrlFromSession(session);
      expect(baseUrl.toString(), 'https://jmap.numberinbox.com');
    });

    test('baseUrlFromSession strips .well-known/jmap suffix', () {
      final mgr = JmapSessionManager();
      final session = OtpSession(
        accessToken: 'jwt',
        username: '+66812345678@numberinbox.com',
        sessionUrl: 'https://jmap.numberinbox.com/.well-known/jmap',
        credential: 'secret',
      );
      final url = mgr.baseUrlFromSession(session);
      expect(url.path, isNot(contains('.well-known')));
    });

    test('wrongCredentialError returns false for valid credential', () {
      final mgr = JmapSessionManager();
      expect(mgr.isCredentialError(401, 'unauthorized'), isTrue);
      expect(mgr.isCredentialError(200, 'ok'), isFalse);
      expect(mgr.isCredentialError(500, 'internal'), isFalse);
    });
  });
}
