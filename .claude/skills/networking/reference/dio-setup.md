# Dio setup

```yaml
dependencies:
  dio: ^5.7.0
  retrofit: ^4.4.0
  json_annotation: ^4.9.0
dev_dependencies:
  retrofit_generator: ^9.0.0
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
```

## Single configured Dio instance (via DI)

Create one Dio, configured with base URL, timeouts, and headers, and share it through your DI container/provider. Never `Dio()` per request.

```dart
Dio buildDio({required AuthStore auth, required Future<void> Function() onRefresh}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.example.com/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.addAll([
    AuthInterceptor(auth),
    RefreshInterceptor(dio, auth, onRefresh),
    if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
  ]);
  return dio;
}
```

## Cancellation

Pass a `CancelToken` from the caller (e.g. cancel a search when the query changes or the screen disposes).

```dart
final cancel = CancelToken();
final result = await repo.fetchAll(cancel: cancel);
// later: cancel.cancel('user left screen');
```

A cancelled request throws a `DioException` of type `cancel`, mapped to a benign failure — handle it without surfacing an error.
