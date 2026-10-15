import 'package:dio/dio.dart';

/// The one way the SDK builds a [Dio].
///
/// Redirects are never followed: the `X-Auth-Token` header must not travel to
/// another host, so a 3xx surfaces as an error. The timeouts keep a stuck
/// server from holding the session lock (or the UI) forever.
Dio chatwootDio(String baseUrl) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    followRedirects: false,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 60), // uploads
  ),
);
