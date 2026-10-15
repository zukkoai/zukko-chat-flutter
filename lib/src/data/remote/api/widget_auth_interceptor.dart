import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';
import 'widget_session.dart';

/// Attaches `website_token` (query) and `X-Auth-Token` to every widget request
/// and repairs a stale session.
///
/// A 404 is ambiguous (unknown JWT, but also "no conversation yet"), so
/// [WidgetSession.recoverFrom404] asks `/config` with the current JWT: if the
/// contact is unchanged the 404 is passed on as is, otherwise the new session
/// is adopted and the request replayed once, through [dio] itself so the fresh
/// headers are attached. Requests marked [noRecover] never trigger recovery.
class WidgetAuthInterceptor extends Interceptor {
  WidgetAuthInterceptor({
    required this.session,
    required this.websiteToken,
    required this.dio,
  });

  /// `extra` flag: a 404 for this request is final (typing, last seen).
  static const noRecover = 'noRecover';
  static const _retried = 'retried';
  static const _generation = 'widgetGeneration';

  final WidgetSession session;
  final String websiteToken;

  /// The authenticated Dio this interceptor is installed on.
  final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      await session.ensureReady();
    } on ChatwootClientException catch (e) {
      return handler.reject(
        DioException(requestOptions: options, error: e, message: e.cause),
      );
    }
    options.queryParameters['website_token'] = websiteToken;
    final jwt = session.authToken;
    if (jwt != null) options.headers['X-Auth-Token'] = jwt;
    options.extra[_generation] = session.generation;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final status = err.response?.statusCode;

    if (status == 401 || status == 410) {
      // the widget (account or inbox) is unavailable; nothing to recover
      final e = ChatwootClientException(
        'the chat widget is unavailable (HTTP $status)',
        ChatwootClientExceptionType.SESSION_EXPIRED,
      );
      return handler.reject(
        DioException(
          requestOptions: options,
          response: err.response,
          error: e,
          message: e.cause,
        ),
      );
    }
    if (status != 404 ||
        options.extra[noRecover] == true ||
        options.extra[_retried] == true) {
      return handler.next(err);
    }

    try {
      final generation = options.extra[_generation];
      final replace = await session.recoverFrom404(
        generation is int ? generation : session.generation,
      );
      if (!replace) return handler.next(err); // a genuine 404

      // A multipart body can be sent only once: replay a copy.
      final body = options.data;
      final retry = options.copyWith(
        data: body is FormData ? body.clone() : body,
        extra: {...options.extra, _retried: true},
      );
      handler.resolve(await dio.fetch<dynamic>(retry));
    } on ChatwootClientException catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e, message: e.cause),
      );
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}
