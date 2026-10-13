# Map DioException → typed Failure (single mapper)

Convert transport errors into domain `Failure` objects in one place. (See the error-handling skill for the `Failure` hierarchy and `Result`.)

```dart
Failure mapDioException(Object error) {
  if (error is! DioException) return const UnexpectedFailure('Unexpected error');
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure('Request timed out');
    case DioExceptionType.connectionError:
      return const NetworkFailure('No internet connection');
    case DioExceptionType.badResponse:
      final code = error.response?.statusCode ?? 0;
      if (code == 401) return const UnauthorizedFailure('Session expired');
      return ServerFailure(
        statusCode: code,
        message: error.response?.data?['message']?.toString() ?? 'Server error',
      );
    case DioExceptionType.cancel:
      return const NetworkFailure('Request cancelled');
    default:
      return const UnexpectedFailure('Unexpected network error');
  }
}
```

- Keep this mapper as the **only** place `DioExceptionType` is interpreted.
- A `cancel` type is benign — surface it quietly (or ignore it in the UI).
- Pull a server-provided message when present (`error.response?.data?['message']`), falling back to a generic string.
