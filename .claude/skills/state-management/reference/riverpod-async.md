# Riverpod AsyncNotifier — load + mutate a list

`AsyncNotifier` is for async state you also mutate. `build` returns the initial `Future<T>`; mutations reassign `state` (an `AsyncValue<T>`).

## Full example

```dart
@riverpod
class TodoList extends _$TodoList {
  TodoRepository get _repo => ref.read(todoRepositoryProvider);

  @override
  Future<List<Todo>> build() => _repo.fetchAll();

  Future<void> add(String title) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.create(title);
      return _repo.fetchAll();
    });
  }

  Future<void> remove(String id) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList()); // NEW list
    final result = await AsyncValue.guard(() => _repo.delete(id));
    if (result.hasError) state = AsyncData(current); // rollback
  }

  Future<void> toggle(String id) async {
    final current = state.value ?? [];
    // optimistic update — build a NEW list with a NEW item instance
    state = AsyncData([
      for (final t in current)
        if (t.id == id) t.copyWith(done: !t.done) else t,
    ]);
    final result = await AsyncValue.guard(() => _repo.toggle(id));
    if (result.hasError) state = AsyncData(current); // rollback
  }
}
```

Key points:
- **`AsyncValue.guard`** runs the callback and converts any throw into `AsyncError`, so errors land in `state` instead of crashing.
- **Set `AsyncLoading` first** when the whole list is being replaced; skip it for optimistic in-place edits (the UI stays responsive).
- **Always build a NEW list** (`.where(...).toList()`, spread, or collection-for) — never `current.add(x)` then reuse `current`.
- **Rollback** by reassigning the captured `current` on error.
- **Read the value with `.value`** — `.valueOrNull` was removed in Riverpod 3; `.value` returns `null` while loading **or** on error (it no longer throws).

## Preserve previous data during reload

`AsyncLoading` drops the cached value by default; pass it forward to avoid a flash of spinner:

```dart
state = AsyncLoading<List<Todo>>().copyWithPrevious(state);
state = await AsyncValue.guard(() => _repo.fetchAll());
```

Or in the UI, render `state.value` while `state.isLoading` is true.

## Reading the future imperatively

```dart
final todos = await ref.read(todoListProvider.future); // awaits current load
```

## guard with a custom error filter

```dart
state = await AsyncValue.guard(
  () => _repo.fetchAll(),
  (error) => error is! AuthException, // rethrow auth errors to a global handler
);
```

## Riverpod 3 niceties

- **Automatic retry on failed init:** a provider whose `build` throws is retried automatically with exponential backoff (≈200ms, doubling up to ≈6.4s). Configure or disable it per-provider or on `ProviderScope`.
- **Offline persistence (experimental, opt-in):** persist a `Notifier`/`AsyncNotifier` to disk with `riverpod_sqflite` so it survives restarts. Still experimental — gate it behind a flag.
