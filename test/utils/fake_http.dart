import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Records every request and answers through [handler] - a real [Dio] runs
/// unmodified on top, including its status validation and interceptors.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  /// Returns `(statusCode, jsonBody)` for a request.
  (int, Object?) Function(RequestOptions options) handler;

  final requests = <RequestOptions>[];

  /// `METHOD path` of every request, in order.
  List<String> get calls => [for (final r in requests) '${r.method} ${r.path}'];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://chat.test'))..httpClientAdapter = adapter;
