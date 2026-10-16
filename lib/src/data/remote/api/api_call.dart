import 'package:dio/dio.dart';

import '../../../core/zukko_chat_client_exception.dart';

/// Runs [request] and parses the response body with [parse].
///
/// Dio already throws a [DioException] for non-2xx responses, so every failure
/// (transport, status, interceptor, malformed body) is mapped to a single
/// [ZukkoChatException] of type [failure].
Future<T> apiCall<T>(
  ZukkoChatExceptionType failure,
  Future<Response<Object?>> Function() request,
  T Function(Object? data) parse,
) async {
  try {
    return parse((await request()).data);
  } on DioException catch (e) {
    final inner = e.error;
    // a typed failure raised by the interceptor (session, HMAC, rate limit)
    // keeps its own type
    if (inner is ZukkoChatException) throw inner;
    throw ZukkoChatException(
      e.message ?? '',
      failure,
      error: e.error,
      stackTrace: e.stackTrace,
    );
  } on ZukkoChatException {
    rethrow;
  } catch (e, st) {
    // untrusted input can fail in ways nobody listed (FormatException,
    // RangeError, ...); the caller only ever sees the typed exception. Only the
    // type is reported: the text may echo response data.
    throw ZukkoChatException(
      'invalid response: ${e.runtimeType}',
      failure,
      error: e,
      stackTrace: st,
    );
  }
}
