import 'package:dio/dio.dart';

/// Request bounds shared by the NumberInbox API clients, without auth policy.
BaseOptions platformApiOptions(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
);
