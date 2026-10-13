# Collections & iterables

## Lazy iterables — don't materialize early

`map`/`where`/`expand` are lazy. Calling `toList()` mid-chain forces an intermediate allocation; call it once at the end (or not at all).

```dart
// Avoid: two intermediate lists
final result = items.map(transform).toList().where(keep).toList();

// Prefer: single lazy pipeline, materialized once
final result = items.map(transform).where(keep).toList();

// Or stay lazy if you only iterate
for (final x in items.map(transform).where(keep)) use(x);
```

Prefer `Iterable` methods (`firstWhere`, `any`, `fold`, `take`) over manual index loops — clearer and often short-circuiting.

## Growable vs fixed lists

If the length is known and final, a fixed-length list avoids growth reallocation.

```dart
final squares = List<int>.generate(n, (i) => i * i, growable: false);
```

Use `growable: true` (default) only when you actually append later.

## const collections

```dart
const supportedLocales = {'en', 'fr', 'de'}; // shared, immutable, no per-call allocation
```

A `const` collection is canonicalized — the same instance is reused on every access, so put fixed lookup sets/maps behind `const`.

## Tight typing

Never leave raw generics or `dynamic`.

```dart
// Avoid: dynamic disables static checking and slows dispatch
dynamic parse(dynamic json) => json['data'];

// Prefer: explicit types, checked statically
List<User> parse(Map<String, dynamic> json) =>
    (json['data'] as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
```
