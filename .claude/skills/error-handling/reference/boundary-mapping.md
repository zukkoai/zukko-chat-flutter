# Boundary mapping & UI handling

## Map exceptions to Failure at the boundary only

`try/catch` lives in data sources/repositories, never in the UI. Convert each exception type to a domain failure.

```dart
class TodoRepository {
  TodoRepository(this._api, this._cache);
  final ApiClient _api;
  final TodoCache _cache;

  Future<Result<List<Todo>>> fetchAll() async {
    try {
      final dtos = await _api.getTodos();
      return Success(dtos.map((d) => d.toDomain()).toList());
    } on DioException catch (e) {
      return Failure(mapDioException(e)); // → ServerFailure/NetworkFailure/...
    } on CacheException catch (e) {
      return Failure(CacheFailure(e.message));
    } catch (e, st) {
      log('TodoRepository.fetchAll', error: e, stackTrace: st);
      return const Failure(UnexpectedFailure('Something went wrong'));
    }
  }
}
```

## Handle Result exhaustively in the UI

Switch over the sealed result/failure so new categories force a compile-time update.

```dart
Future<void> load() async {
  state = const AsyncLoading();
  final result = await _repo.fetchAll();
  state = switch (result) {
    Success(:final value) => AsyncData(value),
    Failure(:final failure) => AsyncError(failure, StackTrace.current),
  };
}
```

Map each failure to a tailored message/action:

```dart
String userMessage(AppFailure f) => switch (f) {
  NetworkFailure() => 'You appear to be offline. Check your connection.',
  TimeoutFailure() => 'That took too long. Please try again.',
  UnauthorizedFailure() => 'Please sign in again.',
  ServerFailure(:final statusCode) => 'Server error ($statusCode). Try later.',
  ValidationFailure(:final message) => message,
  CacheFailure() || UnexpectedFailure() => 'Something went wrong.',
};
```

## User-facing messages vs logging

| Audience | Content |
|----------|---------|
| User | Short, friendly, actionable — from `failure.message` |
| Logs / crash reporter | Full exception, stack trace, request context, status code |

Never show raw exceptions, stack traces, or status payloads to users. Log the technical detail; render the user message.
