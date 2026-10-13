# Async anti-patterns: do / avoid

Concrete fixes for the async mistakes flagged in the core (Dart 3.12).

## 6. Unhandled async errors / unawaited futures
A future started and dropped runs with no one to catch its error — an unhandled
async error crashes the zone (and the app). Either `await` it inside a
`try/catch`, or opt out explicitly with `unawaited`.

```dart
// Avoid: fire-and-forget — if save() throws, the error is unhandled.
void onTap() {
  repo.save(draft); // returns Future<void>, never awaited
}

// Do: await and handle.
Future<void> onTap() async {
  try {
    await repo.save(draft);
  } on IOException catch (e) {
    log.warning('save failed', e);
    rethrow;
  }
}

// Do: deliberately background it — unawaited() documents intent and the
// analyzer's `unawaited_futures` lint stays happy. Still handle the error.
import 'dart:async';
void onTap() {
  unawaited(repo.save(draft).catchError(_reportSaveError));
}

// Do: surface failure as a Future.error, never a sentinel like -1 / null.
Future<int> parseCount(String s) {
  final n = int.tryParse(s);
  return n == null
      ? Future.error(FormatException('not an int: $s'))
      : Future.value(n);
}
```

## 11. Zombie timers / leaked subscriptions
A `Timer` or `StreamSubscription` keeps its callback — and everything the
callback captures — alive forever unless you cancel it. Always cancel in
`dispose`/`onClose`/`tearDown`, and close controllers.

```dart
// Avoid: subscription and timer created, never cancelled.
class _Widget {
  void init(Stream<int> ticks) {
    ticks.listen(_onTick);                       // leaked subscription
    Timer.periodic(const Duration(seconds: 1), _poll); // zombie timer
  }
}

// Do: keep handles and cancel them on teardown.
class _Widget {
  StreamSubscription<int>? _sub;
  Timer? _timer;
  final _controller = StreamController<int>.broadcast();

  void init(Stream<int> ticks) {
    _sub = ticks.listen(_onTick);
    _timer = Timer.periodic(const Duration(seconds: 1), _poll);
  }

  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _controller.close();
  }
}
```

## 21. Swallowing errors
An empty `catch {}` or a bare `catchError` that returns nothing hides bugs and
produces wrong results downstream. Log and rethrow, or convert to a typed
failure the caller can act on.

```dart
// Avoid: the error vanishes; caller gets an empty list and no clue why.
Future<List<Item>> load() async {
  try {
    return await api.fetchItems();
  } catch (_) {
    return []; // silent failure
  }
}

// Do: convert to a typed failure (so callers can branch), and log it.
sealed class LoadResult {}
class LoadOk extends LoadResult { LoadOk(this.items); final List<Item> items; }
class LoadFail extends LoadResult { LoadFail(this.error); final Object error; }

Future<LoadResult> load() async {
  try {
    return LoadOk(await api.fetchItems());
  } catch (e, st) {
    log.severe('fetchItems failed', e, st);
    return LoadFail(e);
  }
}

// Do (alternative): rethrow after logging when the caller should handle it.
Future<List<Item>> loadOrThrow() async {
  try {
    return await api.fetchItems();
  } catch (e, st) {
    log.severe('fetchItems failed', e, st);
    rethrow;
  }
}
```

## 20. Async gaps — stale captured state
After every `await`, the function suspends; other code runs and state may
change before you resume. Re-read or re-check conditions after the gap rather
than trusting values captured before it. In Flutter, guard `BuildContext` with
`mounted` (the `use_build_context_synchronously` lint enforces this).

```dart
// Avoid: `selected` and `mounted` are stale after the await.
Future<void> save(BuildContext context) async {
  final selected = _selectedId;        // captured before the gap
  await repo.commit(selected);
  Navigator.of(context).pop();         // context may be defunct now
}

// Do: re-check after the await.
Future<void> save(BuildContext context) async {
  await repo.commit(_selectedId);
  if (!context.mounted) return;        // re-check across the gap
  Navigator.of(context).pop();
}
```
