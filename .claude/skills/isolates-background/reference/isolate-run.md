# Isolate.run / compute — CPU work off the UI isolate

## Contents
- [When to reach for an isolate](#when-to-reach-for-an-isolate)
- [Isolate.run (Dart 3, preferred)](#isolaterun-dart-3-preferred)
- [compute (older, single-arg)](#compute-older-single-arg)
- [What does NOT need an isolate](#what-does-not-need-an-isolate)
- [Measuring before optimizing](#measuring-before-optimizing)
- [Big byte buffers — TransferableTypedData](#big-byte-buffers--transferabletypeddata)
- [Legacy Isolate.spawn + ports](#legacy-isolatespawn--ports)

## When to reach for an isolate
A single frame budget is ~16ms (60fps) or ~8ms (120fps). Any **synchronous** chunk of CPU work longer than that on the UI isolate drops frames; long enough and Android raises an ANR. Move it to another isolate.

Good candidates: JSON parsing of large payloads, image decode/resize, crypto/hashing, compression, parsing/CSV, heavy computation, large list transforms.

Not candidates: anything that is already async I/O (network, file read, DB query) — see below.

## Isolate.run (Dart 3, preferred)
Takes a closure, runs it on a fresh isolate, returns the result, tears the isolate down. One call, no ports.

```dart
Future<List<Item>> parseItems(String jsonStr) {
  return Isolate.run(() {
    final raw = jsonDecode(jsonStr) as List;          // CPU-heavy
    return raw.map((e) => Item.fromJson(e)).toList();
  });
}
```

Rules:
- The closure (and everything it captures) must be **sendable** — see `sendable-data.md`.
- The return value is sent back (copied) to the caller isolate.
- Prefer pulling the heavy work into a **top-level or static** function so you don't accidentally capture `this`, `ref`, or `context`.

```dart
// top-level — nothing captured
Uint8List _resize(Uint8List bytes) { /* ... */ }

final small = await Isolate.run(() => _resize(original));
```

## compute (older, single-arg)
`compute` predates `Isolate.run`. It takes a top-level/static function and a single message argument.

```dart
Future<List<Item>> parseItems(String jsonStr) => compute(_parse, jsonStr);

List<Item> _parse(String jsonStr) {
  final raw = jsonDecode(jsonStr) as List;
  return raw.map((e) => Item.fromJson(e)).toList();
}
```

Differences vs `Isolate.run`:
- `compute` requires a named function + single argument (bundle multiple args into a record/map).
- `Isolate.run` takes any closure and is more ergonomic for ad-hoc work.
- Both copy args/results across the boundary. Either is fine; default to `Isolate.run` on Dart 3.

## What does NOT need an isolate
Network calls, file reads, database queries, and platform-channel calls are **already asynchronous** — they don't block the isolate while waiting. Wrapping them in `compute`/`Isolate.run` adds isolate-spawn cost and a data copy for no gain, and can break things (e.g. plugin messengers aren't initialized in the new isolate).

```dart
// WRONG — network is I/O, not CPU
final res = await compute((url) => http.get(Uri.parse(url)), apiUrl); // pointless + http won't work right

// RIGHT
final res = await http.get(Uri.parse(apiUrl));
```

Only the **CPU-heavy part after** I/O (e.g. parsing the response body) is an isolate candidate:
```dart
final res = await http.get(uri);                 // I/O on main isolate
final items = await Isolate.run(() => parse(res.body)); // CPU on another isolate
```

## Measuring before optimizing
Don't isolate-ify on a hunch. Profile in profile mode (`flutter run --profile`), watch the DevTools timeline / "UI" thread, and confirm a sync block >16ms. Tiny work in an isolate is *slower* than just doing it inline because of spawn + copy overhead.

## Big byte buffers — TransferableTypedData
Copying a multi-MB `Uint8List` across the boundary is costly. `TransferableTypedData` *moves* (zero-copy transfers) the underlying bytes instead of copying.

```dart
final transferable = TransferableTypedData.fromList([bigBytes]);
final result = await Isolate.run(() {
  final bytes = transferable.materialize().asUint8List(); // now owned here
  return process(bytes);
});
```

## Legacy Isolate.spawn + ports
Before Dart 3, one-shot isolate work meant `Isolate.spawn` + a `ReceivePort` + manual message passing + teardown — verbose and error-prone:

```dart
// LEGACY — prefer Isolate.run for one-shot work
final p = ReceivePort();
await Isolate.spawn(_entry, p.sendPort);
final sendPort = await p.first as SendPort;
// ... manual request/response wiring, then kill the isolate ...
```

Keep `spawn` + ports only for **long-lived** isolates that handle many messages over time (e.g. a persistent worker). For single computations, `Isolate.run` replaces all of this.
