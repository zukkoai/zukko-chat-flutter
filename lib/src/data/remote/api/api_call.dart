import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';

/// Runs [request] and parses the response body with [parse].
///
/// Dio already throws a [DioException] for non-2xx responses, so every failure
/// (transport, status, interceptor, malformed body) is mapped to a single
/// [ZukkoChatException] of type [failure].
Future<T> apiCall<T>(
  ZukkoChatExceptionType failure,
  Future<Response<dynamic>> Function() request,
  T Function(dynamic data) parse,
) async {
  try {
    return parse((await request()).data);
  } on DioException catch (e) {
    final inner = e.error;
    // a typed failure raised by the interceptor (session, HMAC, rate limit)
    // keeps its own type
    if (inner is ZukkoChatException) throw inner;
    throw ZukkoChatException(e.message ?? '', failure);
  } on ZukkoChatException {
    rethrow;
  } on FormatException catch (e) {
    throw ZukkoChatException('invalid response: ${e.message}', failure);
  } catch (e) {
    // untrusted input can fail in ways nobody listed (RangeError, ...); the
    // caller only ever sees the typed exception
    throw ZukkoChatException('invalid response: $e', failure);
  }
}
