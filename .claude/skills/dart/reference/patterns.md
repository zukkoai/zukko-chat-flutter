# Patterns — sealed classes, pattern matching, records, class modifiers

## Pattern matching & switch expressions

Use exhaustive switch expressions instead of if-else chains. The compiler enforces exhaustiveness over sealed types and enums.

```dart
// Avoid
String label(Shape s) {
  if (s is Circle) return 'circle';
  if (s is Square) return 'square';
  return 'unknown';
}

// Prefer: exhaustive switch expression with destructuring
String label(Shape s) => switch (s) {
  Circle(:final radius) => 'circle r=$radius',
  Square(:final side) => 'square s=$side',
};
```

`if-case` for single-pattern checks; `when` guards and relational/logical patterns:

```dart
if (json case {'name': final String name, 'age': final int age}) {
  return User(name: name, age: age);
}

final msg = switch (code) {
  200 || 201 || 204 => 'ok',
  >= 400 && < 500 => 'client error',
  _ => 'other',
};
```

## Records

Use records for lightweight, multiple return values instead of throwaway classes or `List<dynamic>`.

```dart
// Returns a record; destructure at the call site
(int count, String label) summarize(List<int> xs) =>
    (xs.length, xs.isEmpty ? 'empty' : 'has items');

final (count, label) = summarize(data);

// Named fields for clarity
({double lat, double lng}) location() => (lat: 1.0, lng: 2.0);
```

Records are value types: `==` and `hashCode` are structural. Avoid records as public API across module boundaries — use a named class there.

## Class modifiers

| Modifier | Meaning |
| --- | --- |
| `sealed` | Cannot be instantiated; all subtypes known in-library → exhaustive switching |
| `final` | Cannot be extended or implemented outside its library |
| `base` | Can be extended but not implemented (forces inheritance) |
| `interface` | Can be implemented but not extended |
| `mixin` | Composed via `with` |

## Sealed unions

Use `sealed` for closed unions so switches stay exhaustive — the compiler errors if a case is missing.

```dart
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.message);
  final String message;
}

// Exhaustive — compiler errors if a case is missing
String render(Result<int> r) => switch (r) {
  Ok(:final value) => 'ok: $value',
  Err(:final message) => 'err: $message',
};
```

## Enhanced enums

Prefer enhanced enums (with fields/methods) over loose constants. Switching over an enum is exhaustive — no `default` needed.

```dart
enum Currency {
  usd('USD', r'$'),
  eur('EUR', '€'),
  gbp('GBP', '£');

  const Currency(this.code, this.symbol);
  final String code;
  final String symbol;

  static Currency fromCode(String code) =>
      values.firstWhere((c) => c.code == code);
}
```
