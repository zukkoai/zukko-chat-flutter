# Isolates — full examples

## Isolates for CPU-heavy work

The event loop is single-threaded: a long synchronous computation blocks all I/O and freezes the UI. Move heavy CPU work to an isolate.

```dart
// Dart 3: simplest path — runs a function on a fresh isolate, returns its result
final result = await Isolate.run(() => _expensiveParse(bigPayload));

// In Flutter, `compute(_expensiveParse, bigPayload)` is the equivalent helper.
```

## When (and when not) to use them

- **Use** isolates for: parsing large JSON, image processing, crypto, big computations.
- **Don't use** them for I/O — that's what `async`/`await` is for; an isolate adds overhead with no benefit.

## Sendable arguments

Arguments and results are **copied** across the isolate boundary.

- Keep them small and sendable (primitives, lists/maps of sendables, records).
- Avoid sending objects holding sockets, file handles, or closures over captured state that isn't sendable.

```dart
// Avoid: huge object copied in and out
final r = await Isolate.run(() => process(entireDocumentTree));

// Prefer: send the minimal payload, return the minimal result
final summary = await Isolate.run(() => summarize(rawBytes));
```

## Pitfalls checklist

- Uncaught async error: every async path has a `try/catch` or documented `unawaited` with internal handling.
- Not awaiting: never drop a future implicitly; await it or wrap in `unawaited`.
- Memory leaks: every `listen` has a matching `cancel`; every `StreamController` is `close`d.
- Blocking the loop: no heavy synchronous loops on the main isolate — offload to `Isolate.run`.
- Sequential awaits: batch independent futures with `Future.wait`.
