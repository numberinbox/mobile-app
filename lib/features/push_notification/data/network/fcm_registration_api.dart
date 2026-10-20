import 'dart:convert';

import 'package:dio/dio.dart';

/// FCM token accepted by the backend, paired with the server-assigned
/// registration id and the expiry the server calculated for the token.
class FcmRegistrationPayload {
  FcmRegistrationPayload(this.registrationId, this.expiresAt);

  final String registrationId;
  final DateTime expiresAt;
}

/// Thrown when the backend refuses or cannot process the FCM registration.
/// [code] mirrors the backend `error` field, or `network_error` when the
/// response carries no usable error body.
class FcmRegistrationException implements Exception {
  const FcmRegistrationException(this.code);

  final String code;
}

/// Registers and revokes the device FCM token on the NumberInbox API.
///
/// Stalwart exposes no `FirebaseRegistration/set`, so the token is carried by
/// `POST /v1/fcm-registrations` instead of the JMAP `fcm_api.dart` path.
/// Authentication is the same Basic credential the mailbox itself uses.
class FcmRegistrationApi {
  const FcmRegistrationApi(this._dio);

  static const String typeEmail = 'email';

  final Dio _dio;

  Future<FcmRegistrationPayload> register({
    required String token,
    required String deviceClientId,
    required String username,
    required String password,
  }) async {
    final response = await _post(
      '/v1/fcm-registrations',
      data: {
        'token': token,
        'deviceClientId': deviceClientId,
        'type': typeEmail,
      },
      authorization: _basicHeader(username, password),
    );
    return FcmRegistrationPayload(
      response['registrationId'] as String,
      DateTime.parse(response['expiresAt'] as String),
    );
  }

  Future<void> revoke({
    required String registrationId,
    required String username,
    required String password,
  }) async {
    try {
      await _dio.delete<void>(
        '/v1/fcm-registrations/$registrationId',
        options: Options(headers: {
          'Authorization': _basicHeader(username, password),
        }),
      );
    } on DioException {
      throw const FcmRegistrationException('network_error');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> data,
    required String authorization,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: {
          'Authorization': authorization,
        }),
      );
      return response.data!;
    } on DioException catch (error) {
      throw FcmRegistrationException(_errorCode(error));
    }
  }

  String _basicHeader(String username, String password) {
    return 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  String _errorCode(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return 'network_error';
  }
}
