import 'dart:convert';

import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';

/// Thrown when an OTP response points the app at an origin the client was not
/// configured to trust.
///
/// Only [reason] is carried: a fixed category string. The rejected URL and the
/// credential that arrived with it must never reach a log sink, Sentry, or the
/// user-visible error.
class UntrustedJmapSessionUrlException implements Exception {
  const UntrustedJmapSessionUrlException(this.reason);

  /// Fixed, non-identifying category: one of [reasons].
  final String reason;

  static const reasons = <String>{
    'malformed',
    'userinfo',
    'scheme',
    'host',
    'port',
    'trusted_origin_misconfigured',
  };

  @override
  String toString() => 'UntrustedJmapSessionUrlException($reason)';
}

/// Manages JMAP session configuration after OTP login.
///
/// After OTP verification, the app receives an [OtpSession] with the JMAP
/// server URL and credentials. This class bridges the OTP result into the
/// existing Twake Mail credential storage and JMAP client infrastructure.
class JmapSessionManager {
  JmapSessionManager({String? baseUrl}) : _baseUrl = baseUrl;

  static const _jmapPath = '/jmap';

  final String? _baseUrl;

  /// The JMAP server base URL (without trailing path).
  String get baseUrl => _baseUrl ?? AppConfig.jmapBaseUrl;

  /// The full JMAP session endpoint (`{baseUrl}/jmap`).
  String get sessionEndpoint => '$baseUrl$_jmapPath';

  /// The only origin an OTP-issued JMAP credential may be used against.
  ///
  /// Explicit local development configuration goes through the injected
  /// [baseUrl]; a response still has to match that origin, so injection widens
  /// *which* origin is trusted without ever accepting an arbitrary one.
  Uri get trustedOrigin {
    final configured = Uri.tryParse(baseUrl);
    if (configured == null ||
        !configured.hasAuthority ||
        configured.host.isEmpty) {
      throw const UntrustedJmapSessionUrlException(
        'trusted_origin_misconfigured',
      );
    }
    return _originOf(configured);
  }

  /// Extracts the base URL from an [OtpSession]'s `sessionUrl`, stripping
  /// the `.well-known/jmap` suffix so it can be used as the Dio base URL.
  ///
  /// The URL decides where the username and credential from the same response
  /// get sent, so it is only accepted when its origin is exactly
  /// [trustedOrigin]. Anything else — another host, an http downgrade, a
  /// userinfo trick, an alternate port — raises
  /// [UntrustedJmapSessionUrlException] and no credential is used.
  Uri baseUrlFromSession(OtpSession session) {
    final uri = Uri.tryParse(session.sessionUrl);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.host.contains('%')) {
      throw const UntrustedJmapSessionUrlException('malformed');
    }

    // `https://jmap.numberinbox.com@evil.example` parses with the configured
    // host in userinfo and the real host in `host`; refusing userinfo outright
    // also removes the backslash variant, since Dart reads `\` as `/`.
    if (uri.userInfo.isNotEmpty) {
      throw const UntrustedJmapSessionUrlException('userinfo');
    }

    final trusted = trustedOrigin;

    if (uri.scheme.toLowerCase() != trusted.scheme) {
      throw const UntrustedJmapSessionUrlException('scheme');
    }

    if (uri.host.toLowerCase() != trusted.host) {
      throw const UntrustedJmapSessionUrlException('host');
    }

    if (_effectivePort(uri) != trusted.port) {
      throw const UntrustedJmapSessionUrlException('port');
    }

    // sessionUrl is typically "https://jmap.numberinbox.com/.well-known/jmap"
    // We want just the trusted origin: "https://jmap.numberinbox.com"
    return _originOf(uri);
  }

  /// Scheme, host and effective port only, so the result cannot keep a path,
  /// query or fragment that the trusted origin check never looked at.
  static Uri _originOf(Uri uri) => Uri(
        scheme: trustedSchemeOf(uri),
        host: uri.host.toLowerCase(),
        port: _effectivePort(uri),
      );

  /// Lowercased scheme, since [Uri] leaves the scheme as written.
  static String trustedSchemeOf(Uri uri) => uri.scheme.toLowerCase();

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return switch (trustedSchemeOf(uri)) {
      'https' => 443,
      'http' => 80,
      _ => uri.port,
    };
  }

  /// Builds the `Authorization: Basic ...` header value from an [OtpSession].
  /// Uses `credential` as the password (not `accessToken`).
  String buildBasicAuthHeader(OtpSession session) {
    final decoded = decodeBasicAuth(session);
    return 'Basic ${base64Encode(utf8.encode('${decoded['username']}:${decoded['password']}'))}';
  }

  /// Decodes an [OtpSession] into the username/password pair used for
  /// JMAP Basic Auth. Returns a map with keys `username` and `password`.
  Map<String, String> decodeBasicAuth(OtpSession session) {
    return {
      'username': session.username,
      'password': session.credential,
    };
  }

  /// Returns `true` if the given HTTP status/error indicates the JMAP
  /// credential is invalid (user should be redirected to login).
  bool isCredentialError(int statusCode, String? error) {
    return statusCode == 401;
  }
}
