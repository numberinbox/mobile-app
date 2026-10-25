import 'package:dio/dio.dart';

/// Calls the backend reset server running on the CI host.
///
/// Only active when RESET_SERVER_URL is provided via --dart-define,
/// so local runs without the reset server are unaffected.
///
/// Uses Dio instead of dart:io so it works on all platforms including web.
class BackendResetClient {
  static const String _resetUrl = String.fromEnvironment(
    'RESET_SERVER_URL',
    defaultValue: '',
  );

  static bool get isEnabled => _resetUrl.isNotEmpty;

  /// Sends POST /reset and waits for the backend to confirm readiness.
  /// Times out after [timeout] (default 3 minutes to allow container restart).
  static Future<void> reset({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (!isEnabled) return;

    final dio = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );

    try {
      await BackendResetRequest(dio).reset(_resetUrl, timeout: timeout);
    } finally {
      dio.close();
    }
  }
}

/// The small HTTP boundary used by [BackendResetClient] and its tests.
class BackendResetRequest {
  const BackendResetRequest(this._dio);

  final Dio _dio;

  Future<void> reset(
    String resetUrl, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (resetUrl.isEmpty) return;

    try {
      final response = await _dio.post(
        '$resetUrl/reset',
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode != 200) {
        throw const BackendResetException();
      }
    } on BackendResetException {
      rethrow;
    } catch (_) {
      // Dio errors can contain URLs, response bodies, or request headers.
      // Keep teardown failures actionable without retaining any of that data.
      throw const BackendResetException();
    }
  }
}

class BackendResetException implements Exception {
  const BackendResetException();

  @override
  String toString() => 'Backend reset failed';
}
