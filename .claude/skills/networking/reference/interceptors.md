# Interceptors

## Auth — inject Bearer token in onRequest

```dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._auth);
  final AuthStore _auth;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _auth.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
```

## Token refresh on 401 — lock, refresh, retry

Lock dio while refreshing so queued requests wait, refresh the token, then retry the failed request. Guard with an `extra['retried']` flag so a request is retried at most once.

```dart
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor(this._dio, this._auth, this._refresh);
  final Dio _dio;
  final AuthStore _auth;
  final Future<void> Function() _refresh;

  @override
  Future<void> onError(DioException e, ErrorInterceptorHandler handler) async {
    if (e.response?.statusCode != 401 || e.requestOptions.extra['retried'] == true) {
      return handler.next(e);
    }
    _dio.lock(); // pause new requests
    try {
      await _refresh(); // updates _auth.accessToken
    } catch (_) {
      _dio.unlock();
      return handler.next(e); // refresh failed → surface 401
    }
    _dio.unlock();
    try {
      final opts = e.requestOptions
        ..extra['retried'] = true
        ..headers['Authorization'] = 'Bearer ${_auth.accessToken}';
      final clone = await _dio.fetch(opts);
      return handler.resolve(clone);
    } on DioException catch (err) {
      return handler.next(err);
    }
  }
}
```

## Logging — debug only

`LogInterceptor` guarded by `kDebugMode`. Never log bodies/tokens in release builds.

```dart
if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
```
