import 'package:dio/dio.dart';

import 'e164.dart';

class InvalidE164Exception implements Exception {}

class OtpInvalidException implements Exception {}

class RateLimitedException implements Exception {}

class OtpUnknownException implements Exception {
  OtpUnknownException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NumberInboxAuthClient {
  NumberInboxAuthClient(this._dio);

  final Dio _dio;

  Future<void> startOtp(String rawE164) async {
    final e164 = normalizeE164(rawE164);
    try {
      await _dio.post('/v1/otp/start', data: {'e164': e164});
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Future<OtpSession> verifyOtp(String rawE164, String code) async {
    final e164 = normalizeE164(rawE164);
    try {
      final response = await _dio.post('/v1/otp/verify',
          data: {'e164': e164, 'code': code});
      final data = response.data as Map<String, dynamic>;
      final jmap = data['jmap'] as Map<String, dynamic>;
      return OtpSession(
        accessToken: data['accessToken'] as String,
        username: jmap['username'] as String,
        sessionUrl: jmap['sessionUrl'] as String,
        credential: jmap['credential'] as String,
      );
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  Exception mapError(DioException e) {
    final code = (e.response?.data as Map<String, dynamic>?)?['error'] as String?;
    switch (code) {
      case 'invalid_e164':
        return InvalidE164Exception();
      case 'otp_invalid':
        return OtpInvalidException();
      case 'rate_limited':
        return RateLimitedException();
      default:
        return OtpUnknownException(_friendlyMessage(e));
    }
  }

  String _friendlyMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Please try again.';
      case DioExceptionType.badResponse:
        return 'Server error. Please try again.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

class OtpSession {
  const OtpSession({
    required this.accessToken,
    required this.username,
    required this.sessionUrl,
    required this.credential,
  });

  final String accessToken;
  final String username;
  final String sessionUrl;
  final String credential;
}
