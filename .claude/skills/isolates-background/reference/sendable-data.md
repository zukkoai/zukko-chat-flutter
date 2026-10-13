# What can cross an isolate boundary

## Contents
- [The model: no shared memory](#the-model-no-shared-memory)
- [Sendable types](#sendable-types)
- [NOT sendable — anti-examples](#not-sendable--anti-examples)
- [Bundling multiple args](#bundling-multiple-args)
- [Returning results](#returning-results)

## The model: no shared memory
Isolates have **separate heaps**. Nothing is shared. When you pass an argument into `Isolate.run`/`compute` or send a message over a port, Dart **copies** it (or, for a few types, *moves* it). Mutating a list inside the isolate does **not** change the original on the caller side.

This is why you cannot pass live objects that hold native handles, framework state, or open connections — those can't be copied and have no meaning in another heap.

## Sendable types
Safe to send (copied):
- Primitives: `int`, `double`, `bool`, `String`, `null`.
- Collections of sendable values: `List`, `Map`, `Set`, records.
- Typed data: `Uint8List`, `ByteData`, etc.
- Plain data objects (DTOs/models) built only from the above — your own `class Item { final String name; ... }` is fine if its fields are sendable.
- `SendPort` (for long-lived isolate comms).
- `RootIsolateToken` (to re-init plugin messengers — see `plugins-in-isolates.md`).
- `TransferableTypedData` (moved, not copied — for big buffers).

## NOT sendable — anti-examples
These throw or make no sense across the boundary. Known AI mistakes:

```dart
// ❌ BuildContext — UI tree lives on the UI isolate only
Isolate.run(() => doThing(context));        // never

// ❌ A live DB connection / Isar / sqflite Database handle
Isolate.run(() => db.query(...));           // native handle, not copyable

// ❌ A plugin instance or its channel
Isolate.run(() => myPlugin.fetch());        // messenger not initialized in the new isolate

// ❌ Riverpod ref / Bloc / ChangeNotifier
Isolate.run(() => ref.read(repoProvider));  // framework state, not sendable

// ❌ Closures capturing any of the above
final repo = this.repo;
Isolate.run(() => repo.parse(data));        // captures `repo` → may capture non-sendable state
```

Fixes:
- Extract just the **plain data** the work needs and pass that.
- Do the I/O (DB read, network) on the main isolate, send only the resulting bytes/strings into the isolate for CPU work.
- If the isolate genuinely needs a plugin, initialize the background messenger inside it (see `plugins-in-isolates.md`).

```dart
// ✅ pull plain data out first
final rows = await db.rawQuery('SELECT * FROM big'); // I/O on main isolate
final summary = await Isolate.run(() => summarize(rows)); // CPU on data only
```

## Bundling multiple args
`Isolate.run` closures can capture multiple sendable values directly. With `compute` (single message), bundle into a record or map:

```dart
final out = await Isolate.run(() => transform(input, factor, mode)); // captures all three

// compute equivalent
final out = await compute(_transform, (input: input, factor: factor, mode: mode));
List<int> _transform((({List<int> input, double factor, String mode})) a) => ...;
```

## Returning results
The return value is sent back to the caller and must also be sendable. Return DTOs/primitives/collections — never a widget, a stream, or a live handle.

```dart
// ✅ returns sendable data
final List<Item> items = await Isolate.run(() => parse(jsonStr));

// ❌ can't return a Stream or a Widget from the isolate
```
