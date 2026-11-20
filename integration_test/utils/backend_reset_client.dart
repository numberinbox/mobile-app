import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';

import 'test_backend.dart';

/// Leases and releases isolated backends on the backend reset server running on the CI host.
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

  static Future<void> reset({Duration timeout = const Duration(minutes: 3)}) async {
    if (!isEnabled) return;

    final dio = _newDio(timeout);
    try {
      await BackendResetRequest(dio).reset(_resetUrl, timeout: timeout);
    } finally {
      dio.close();
    }
  }

  /// Leases a backend; the server holds the request until one is free.
  static Future<TestBackend> lease({
    // Server answers by LEASE_TIMEOUT (150 s); stays under TestBase's 4 min test timeout.
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final dio = _newDio(timeout);
    try {
      final response = await dio.post<Map<String, dynamic>>('$_resetUrl/lease');
      final data = response.data!;
      return TestBackend(url: data['url'] as String, token: data['token'] as String);
    } catch (_) {
      throw StateError('Backend lease failed');
    } finally {
      dio.close();
    }
  }

  /// Hands the backend back; the server replaces it in the background.
  static Future<void> release(
    TestBackend backend, {
    Duration timeout = const Duration(minutes: 1),
  }) async {
    final token = backend.token;
    if (!isEnabled || token == null) return;

    final dio = _newDio(timeout);
    try {
      await dio.post('$_resetUrl/release', data: {'token': token});
    } catch (_) {
      // The server reclaims an unreleased lease after LEASE_TTL, so a passed test must not fail here.
      logWarning('Backend release failed');
    } finally {
      dio.close();
    }
  }

  static Dio _newDio(Duration timeout) => Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );
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
