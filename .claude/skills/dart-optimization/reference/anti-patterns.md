# Optimization anti-patterns: do / avoid

The big performance trap in Dart typing is `dynamic`. Type safety is not just
correctness — it's speed. (Dart 3.12.)

## 24. `dynamic` / loose typing
`dynamic` disables static checking, forces runtime type lookups on every member
access, and prevents the compiler from specializing or inlining. Values often
get boxed because the compiler can't prove a concrete representation. Use precise
static types so the optimizer can do its job.

```dart
// Avoid: dynamic defeats type checks AND costs at runtime.
dynamic sumAll(dynamic items) {
  var total = 0;            // inferred dynamic via the loop below
  for (var x in items) {    // `items` is dynamic → runtime iterator lookup
    total += x;             // dynamic `+` → runtime dispatch each iteration
  }
  return total;
}

// Do: concrete types → static dispatch, no boxing, inlinable.
int sumAll(List<int> items) {
  var total = 0;
  for (final x in items) {
    total += x;
  }
  return total;
}
```

Why the typed version is faster:
- **No dynamic dispatch**: `+` and iteration resolve at compile time, not via a
  runtime method lookup per element.
- **Less boxing**: with `List<int>` the compiler can keep values unboxed where it
  would otherwise box every `dynamic`.
- **Static errors instead of runtime ones**: a type mismatch is caught at
  compile time, so you never pay to discover it in production.

```dart
// Avoid: raw generic also reintroduces dynamic element access.
num maxOf(List xs) => xs.reduce((a, b) => a > b ? a : b); // a, b are dynamic

// Do: a bounded generic keeps the element type precise.
T maxOf<T extends num>(List<T> xs) => xs.reduce((a, b) => a > b ? a : b);
```

Enforce it with the analyzer (`strict-raw-types`, `avoid_dynamic_calls`) so
loose typing can't slip back into hot paths.
