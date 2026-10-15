import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';

/// Runs [request] and parses the response body with [parse].
///
/// Dio already throws a [DioException] for non-2xx responses, so every failure
/// (transport, status, interceptor, malformed body) is mapped to a single
/// [ChatwootClientException] of type [failure].
Future<T> apiCall<T>(
  ChatwootClientExceptionType failure,
  Future<Response<dynamic>> Function() request,
  T Function(dynamic data) parse,
) async {
  try {
    return parse((await request()).data);
  } on DioException catch (e) {
    final inner = e.error;
    // a typed failure raised by the interceptor (session, HMAC, rate limit)
    // keeps its own type
    if (inner is ChatwootClientException) throw inner;
    throw ChatwootClientException(e.message ?? '', failure);
  } on ChatwootClientException {
    rethrow;
  } on FormatException catch (e) {
    throw ChatwootClientException('invalid response: ${e.message}', failure);
  } catch (e) {
    // untrusted input can fail in ways nobody listed (RangeError, ...); the
    // caller only ever sees the typed exception
    throw ChatwootClientException('invalid response: $e', failure);
  }
}
