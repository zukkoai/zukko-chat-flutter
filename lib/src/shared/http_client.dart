import 'package:dio/dio.dart';

/// The one way the SDK builds a [Dio].
///
/// Redirects are never followed: the `X-Auth-Token` header must not travel to
/// another host, so a 3xx surfaces as an error. The timeouts keep a stuck
/// server from holding the session lock (or the UI) forever.
Dio zukkoChatDio(String baseUrl) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    followRedirects: false,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    sendTimeout: sendTimeout,
  ),
);

const connectTimeout = Duration(seconds: 15);
const receiveTimeout = Duration(seconds: 30);

/// Default for a request body; a file upload sets its own, longer one.
const sendTimeout = Duration(seconds: 60);
