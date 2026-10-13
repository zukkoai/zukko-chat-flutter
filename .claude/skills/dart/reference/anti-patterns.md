# Dart anti-patterns: do / avoid

Concrete fixes for the common mistakes flagged in the core. Each pair shows the
trap and the idiomatic replacement (Dart 3.12).

## 1. Unnecessary `!` (bang) / nullable misuse
Don't silence the compiler with `!` — it converts a maybe-null into a guaranteed
crash. Promote, default, or guard instead.

```dart
// Avoid: bang to make the type-checker stop complaining.
String greet(User? user) => 'Hi ${user!.name}'; // throws if user is null

// Do: null-aware access + default.
String greet(User? user) => 'Hi ${user?.name ?? 'guest'}';

// Do: promote with a null check (the analyzer narrows `user` to non-null).
String greetChecked(User? user) {
  if (user == null) return 'Hi guest';
  return 'Hi ${user.name}'; // no `!` needed — promoted to User
}

// Do: `late` only when the value is truly guaranteed before first read.
late final Database _db; // assigned once in init(), read only after
```

## 14. Copy-paste programming (DRY)
Duplicated logic drifts out of sync; fix it once, in one place.

```dart
// Avoid: the same discount math pasted in two methods.
double priceForMember(double base) => base - base * 0.1 + base * 0.07;
double priceForGuest(double base)  => base - base * 0.0 + base * 0.07;

// Do: extract the shared calculation.
double _withTax(double net) => net + net * 0.07;
double priceForMember(double base) => _withTax(base * 0.9);
double priceForGuest(double base)  => _withTax(base);
```

## 16. Magic numbers / strings
Bare literals hide meaning and invite typos; name them once.

```dart
// Avoid: what is 3? what strings are valid?
if (attempts > 3) lockOut();
if (role == 'admin') showPanel();

// Do: named constants + an enum for a closed set.
const maxAttempts = 3;
enum Role { admin, editor, viewer }

if (attempts > maxAttempts) lockOut();
if (role == Role.admin) showPanel();
```

## 17. Dead code
Unused symbols are noise the reader must still parse. The analyzer flags
`unused_local_variable`, `unused_import`, `unused_element` — delete what it finds.

```dart
// Avoid: import never used, variable computed and dropped, private method never called.
import 'dart:math'; // unused
int total(List<int> xs) {
  final unused = xs.length; // unused_local_variable
  return xs.fold(0, (a, b) => a + b);
}
void _legacyHelper() {} // unused_element

// Do: keep only live code.
int total(List<int> xs) => xs.fold(0, (a, b) => a + b);
```

## 18. God class (Single Responsibility)
One class that fetches, parses, caches, and renders changes for many reasons.
Split it along its responsibilities.

```dart
// Avoid: a class that does I/O + parsing + presentation.
class UserManager {
  Future<String> _httpGet(String url) async => '...';
  User _parse(String json) => User.fromJson(json);
  String render(User u) => '<b>${u.name}</b>';
  Future<String> show(int id) async => render(_parse(await _httpGet('/u/$id')));
}

// Do: one reason to change per class.
class UserApi { Future<String> get(int id) async => '...'; }
class UserParser { User parse(String json) => User.fromJson(json); }
class UserView { String render(User u) => '<b>${u.name}</b>'; }
```

## 23. `late` not initialized → LateInitializationError
`late` without a guaranteed write is a deferred crash. Prefer `late final`
initialized at construction, or just make it nullable.

```dart
// Avoid: may be read before any assignment.
class Cart {
  late double total; // LateInitializationError if `checkout()` runs first
  void addItems(List<double> xs) => total = xs.fold(0, (a, b) => a + b);
  double checkout() => total; // throws if addItems() never ran
}

// Do: initialize in the constructor (late final), or model "not yet set" as null.
class Cart {
  Cart(List<double> xs) : total = xs.fold(0, (a, b) => a + b);
  final double total;
}

class CartNullable {
  double? total; // explicit "maybe not computed yet"
  double checkout() => total ?? 0;
}
```

## 24. `dynamic` overuse / loose typing
`dynamic` turns off static checking — errors surface at runtime, dispatch is
slower. Use precise types and bounded generics.

```dart
// Avoid: dynamic everywhere, raw generic.
dynamic firstOrNull(List items) => items.isEmpty ? null : items[0];

// Do: a generic with a precise return type.
T? firstOrNull<T>(List<T> items) => items.isEmpty ? null : items.first;

// Do: bound the type parameter when you need members of a base type.
num maxValue<T extends num>(List<T> xs) => xs.reduce((a, b) => a > b ? a : b);
```

## 29. Spaghetti code
Long functions with deep `if`/`else` and nested callbacks are hard to follow.
Use early returns, small helpers, and `switch` expressions.

```dart
// Avoid: arrow-shaped nesting.
String label(int? score) {
  if (score != null) {
    if (score >= 90) {
      return 'A';
    } else {
      if (score >= 80) {
        return 'B';
      } else {
        return 'C';
      }
    }
  } else {
    return 'n/a';
  }
}

// Do: early return + switch expression with guards.
String label(int? score) {
  if (score == null) return 'n/a';
  return switch (score) {
    >= 90 => 'A',
    >= 80 => 'B',
    _ => 'C',
  };
}
```

## 25/26. Skipping fundamentals
Heavy abstractions (DI containers, reactive frameworks, code-gen) amplify
mistakes when the basics aren't solid. Before relying on them, be fluent in:

- **Null safety** — `?`, `!`, `??`, `??=`, promotion, `late`.
- **async/await** — `Future`, `await`, error propagation, `unawaited`.
- **Streams** — single vs broadcast, `async*`/`yield`, cancellation.

A bug in these fundamentals will defeat any abstraction layered on top.
