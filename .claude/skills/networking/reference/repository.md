# Repository returns Result

The repository wraps the retrofit client, catches errors at this boundary only, and returns a `Result` so the UI handles outcomes exhaustively without try/catch.

```dart
class TodoRepository {
  TodoRepository(this._api);
  final ApiClient _api;

  Future<Result<List<Todo>>> fetchAll({CancelToken? cancel}) async {
    try {
      final dtos = await _api.getTodos(1);
      return Success(dtos.map((d) => d.toDomain()).toList());
    } catch (e) {
      return Failure(mapDioException(e));
    }
  }
}
```

## Rules
- One Dio instance, configured once, injected everywhere.
- All cross-cutting concerns (auth, refresh, logging) live in interceptors.
- No `jsonDecode` / `try/catch` inside retrofit interfaces.
- Exceptions become `Failure` at the data-layer boundary; layers above receive `Result`.
- Map DTO → domain inside the repository; never leak DTOs upward.

See the error-handling skill for the `Result<T>` / `Failure` definitions and exhaustive handling in the UI.
