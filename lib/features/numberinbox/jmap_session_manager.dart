import 'dart:convert';

import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';

/// Manages JMAP session configuration after OTP login.
///
/// After OTP verification, the app receives an [OtpSession] with the JMAP
/// server URL and credentials. This class bridges the OTP result into the
/// existing Twake Mail credential storage and JMAP client infrastructure.
class JmapSessionManager {
  JmapSessionManager({String? baseUrl}) : _baseUrl = baseUrl;

  static const _defaultBaseUrl = 'https://jmap.numberinbox.com';
  static const _jmapPath = '/jmap';

  final String? _baseUrl;

  /// The JMAP server base URL (without trailing path).
  String get baseUrl => _baseUrl ?? _defaultBaseUrl;

  /// The full JMAP session endpoint (`{baseUrl}/jmap`).
  String get sessionEndpoint => '$baseUrl$_jmapPath';

  /// Extracts the base URL from an [OtpSession]'s `sessionUrl`, stripping
  /// the `.well-known/jmap` suffix so it can be used as the Dio base URL.
  Uri baseUrlFromSession(OtpSession session) {
    final uri = Uri.parse(session.sessionUrl);
    // sessionUrl is typically "https://jmap.numberinbox.com/.well-known/jmap"
    // We want just "https://jmap.numberinbox.com"
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final wellKnownIndex = segments.indexOf('.well-known');
    if (wellKnownIndex >= 0) {
      // Build path up to .well-known (i.e., just the host prefix)
      return uri.replace(path: '', query: null, fragment: null);
    }
    // If no .well-known, just use the origin
    return uri.replace(path: '', query: null, fragment: null);
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
