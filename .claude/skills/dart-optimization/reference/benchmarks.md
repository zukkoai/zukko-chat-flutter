# Before / after

## StringBuffer vs concatenation

Each `+` on a `String` allocates a new object — O(n²) in a loop. Use `StringBuffer`.

```dart
// Avoid: O(n^2) allocations
var out = '';
for (final item in items) out += '${item.name}, ';

// Prefer: O(n)
final buffer = StringBuffer();
for (final item in items) buffer.write('${item.name}, ');
final out = buffer.toString();
```

## Avoid allocations in loops

```dart
// Avoid: new RegExp every iteration
for (final s in lines) {
  if (RegExp(r'\d+').hasMatch(s)) count++;
}

// Prefer: build once
final digits = RegExp(r'\d+');
for (final s in lines) {
  if (digits.hasMatch(s)) count++;
}
```

## const canonicalization

```dart
// Avoid: new instance each time
final padding = EdgeInsets.all(16);
final colors = [Colors.red, Colors.blue];

// Prefer: built once, shared
const padding = EdgeInsets.all(16);
const colors = [Colors.red, Colors.blue];
```

## Switch expressions over if-else chains

Switch expressions compile efficiently and are exhaustiveness-checked over enums and sealed types.

```dart
// Avoid
String label;
if (s == Status.active) {
  label = 'Active';
} else if (s == Status.inactive) {
  label = 'Inactive';
} else {
  label = 'Unknown';
}

// Prefer
final label = switch (s) {
  Status.active => 'Active',
  Status.inactive => 'Inactive',
  Status.pending => 'Pending',
};
```

## Pattern matching instead of double casts

```dart
// Avoid: type-check, then cast again
if (result is Ok) {
  final data = (result as Ok).value;
}

// Prefer: one destructuring
if (result case Ok(value: final data)) {
  use(data);
}
```

## Isolates for heavy computation

CPU-bound work (large JSON parse, image processing) blocks the single-threaded event loop. Offload it with `Isolate.run` — see the `async` skill for the full pattern.

```dart
final parsed = await Isolate.run(() => expensiveParse(payload));
```

## late initialization

Use `late final` for expensive values needed lazily; avoid `late` for async-set fields (reading before assignment throws `LateInitializationError`).

```dart
late final _cache = HashMap<String, User>(); // built on first access
```
