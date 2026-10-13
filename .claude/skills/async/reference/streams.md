# Streams — full examples

## Single vs broadcast

A single-subscription stream allows one listener; a broadcast stream allows many. Listening twice to a single-subscription stream throws.

```dart
final controller = StreamController<int>();            // single-subscription
final bus = StreamController<int>.broadcast();         // many listeners
```

## Producing streams with async*/yield

```dart
Stream<int> countdown(int from) async* {
  for (var i = from; i >= 0; i--) {
    yield i;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

await for (final n in countdown(3)) {
  print(n); // 3, 2, 1, 0
}
```

`await for` cancels the subscription automatically when the loop exits or throws.

## Cancellation & leak prevention

Manually-managed subscriptions must be cancelled, and controllers must be closed, or they leak memory and keep callbacks alive.

```dart
StreamSubscription<int>? _sub;

void start(Stream<int> source) {
  _sub = source.listen(_onData, onError: _onError);
}

Future<void> dispose() async {
  await _sub?.cancel();   // always cancel
  await _controller.close();
}
```

- Every `listen` needs a matching `cancel`.
- Every `StreamController` needs a `close`.
- Lints `cancel_subscriptions` and `close_sinks` catch the common misses.
