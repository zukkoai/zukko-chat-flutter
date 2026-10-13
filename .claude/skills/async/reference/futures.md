# Futures — full examples

## async/await and error handling

Always `await` futures and handle errors with `try/catch`. Return failures via `throw` or `Future.error`, never a sentinel.

```dart
Future<User> fetchUser(String id) async {
  try {
    final res = await api.get('/users/$id');
    return User.fromJson(res.data);
  } on TimeoutException {
    throw const NetworkException('timeout');
  } catch (e, st) {
    log.severe('fetchUser failed', e, st);
    rethrow;
  }
}
```

## Parallelism: avoid sequential awaits

Sequential `await`s run one after another. Use `Future.wait` (or record `.wait`) to run independent futures concurrently.

```dart
// Avoid: total time = a + b + c
final a = await fetchA();
final b = await fetchB();
final c = await fetchC();

// Prefer: total time = max(a, b, c)
final (a, b, c) = await (fetchA(), fetchB(), fetchC()).wait; // record .wait
// or
final results = await Future.wait([fetchA(), fetchB(), fetchC()]);
```

`Future.wait` rejects on the first error. With `eagerError: false` (default) the other futures still run; add per-future `.catchError` if you need every result regardless of failures.

## unawaited()

If you intentionally don't await a future (fire-and-forget), mark it with `unawaited` so the analyzer and reader know it's deliberate.

```dart
import 'dart:async';

unawaited(analytics.logEvent('opened')); // intentional; errors handled internally
```

Avoid silently dropping a future — unhandled async errors crash the zone.

## Debounce & throttle

```dart
// Debounce: fire only after input pauses
Timer? _debounce;
void onChanged(String q) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () => search(q));
}
```

Cancel the timer in `dispose` to avoid a leak. For stream-based debounce/throttle, use `package:rxdart` operators (`debounceTime`, `throttleTime`) rather than reinventing them.
