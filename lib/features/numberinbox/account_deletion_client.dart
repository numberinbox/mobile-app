import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/e164.dart';

class AccountDeletionRequest {
  const AccountDeletionRequest(this.requestId, this.statusToken);

  final String requestId;
  final String statusToken;
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.code);

  final String code;
}

class AccountDeletionClient {
  const AccountDeletionClient(this._dio);

  final Dio _dio;

  Future<AccountDeletionRequest> request({
    required String confirmE164,
    required String username,
    required String password,
    required String idempotencyKey,
  }) async {
    final authorization = base64Encode(utf8.encode('$username:$password'));
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/account-deletions',
        data: {'confirmE164': normalizeE164(confirmE164)},
        options: Options(headers: {
          'Authorization': 'Basic $authorization',
          'Idempotency-Key': idempotencyKey,
        }),
      );
      final data = response.data!;
      return AccountDeletionRequest(
        data['requestId'] as String,
        data['statusToken'] as String,
      );
    } on DioException catch (error) {
      throw AccountDeletionException(_errorCode(error));
    }
  }

  Future<String> status(String requestId, String statusToken) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/account-deletions/$requestId',
        options: Options(headers: {'Authorization': 'Bearer $statusToken'}),
      );
      return response.data!['status'] as String;
    } on DioException catch (error) {
      throw AccountDeletionException(_errorCode(error));
    }
  }

  String _errorCode(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['error'] is String) {
      return data['error'] as String;
    }
    return 'network_error';
  }
}
