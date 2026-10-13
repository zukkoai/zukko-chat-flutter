# Extensions & mixins — static dispatch, linearization, operators

The non-obvious footguns. Basic extension syntax is in `naming-and-style.md`;
enhanced enums and class modifiers (`sealed`/`base`/`interface`/`final`/`mixin`)
are in `patterns.md` — not repeated here.

## Contents
- [Extensions: static dispatch](#extensions-static-dispatch)
- [Extensions: import scope & conflicts](#extensions-import-scope--conflicts)
- [Extensions on nullable types](#extensions-on-nullable-types)
- [Instance members shadow extensions](#instance-members-shadow-extensions)
- [Mixins: the `on` constraint](#mixins-the-on-constraint)
- [Mixins: linearization order](#mixins-linearization-order)
- [`mixin` vs `mixin class`](#mixin-vs-mixin-class)
- [Mixins have no constructors](#mixins-have-no-constructors)
- [Callable classes (`call`)](#callable-classes-call)
- [Custom operators](#custom-operators)

## Extensions: static dispatch

The single biggest footgun: **extension method dispatch is static** — resolved on
the receiver's **static type**, not its runtime type. This is the opposite of
normal (virtual) method dispatch. When several extensions apply, the one with the
**most specific `on` type** wins, decided at compile time.

```dart
extension NumX on num { String kind() => 'num'; }
extension IntX on int { String kind() => 'int'; }

num n = 3;                  // static type: num   runtime type: int
n.kind();                   // 'num'  ← chosen on the STATIC type, not runtime int
(n as int).kind();          // 'int'  ← the cast changes the static type
3.kind();                   // 'int'  ← literal's static type is int; IntX is more specific
```

Consequence: a function typed `T process<T>(T x)` calling `x.someExt()` resolves
against `T`'s bound, never the concrete runtime argument — extensions and generics
mix badly. If you need runtime behavior, use a real method/`switch`, not an
extension.

## Extensions: import scope & conflicts

An extension's members exist **only in libraries that import the file declaring
it** — they are not part of the type. Import the extension's library or the member
silently does not exist. You can gate them with `show`/`hide`.

When two in-scope extensions declare the same member on overlapping types, the
call is **ambiguous and fails to compile**. Disambiguate by applying the
extension explicitly as if it were a constructor:

```dart
// Avoid: both ApiX and DbX define `.parsed` on String → ambiguous_extension_member_access
final v = raw.parsed;

// Do: name the extension explicitly
final v = ApiX(raw).parsed;
```

Unnamed extensions (`extension on Foo { … }`) can't be applied explicitly, so they
can't be disambiguated — **name any extension** you might collide on.

## Extensions on nullable types

`on T?` lets you call the method on a `null` receiver — because dispatch is static,
there is no null-check before the call. Inside, `this` may be null; you must guard.
This is the one case you can "call a method on null" without a crash.

```dart
extension StringOrNull on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
}

String? s;
s.isNullOrBlank;   // true — no NoSuchMethodError, even though s is null
```

## Instance members shadow extensions

A real instance member **always** beats an extension member of the same name —
even a future one added to the class later. The extension becomes dead code with
no error, so a library upgrade can silently change behavior.

```dart
class Box { int size() => 1; }
extension on Box { int size() => 2; }

Box().size();   // 1 — the instance method wins; the extension never runs
```

## Mixins: the `on` constraint

`mixin M on S` restricts `M` to classes that are (or extend) `S`, and in return
lets `M` call `S`'s members via `super`. Use it to layer behavior onto a known
base instead of duplicating it.

```dart
abstract class Animal { String speak(); }

mixin Loud on Animal {
  String shout() => '${speak().toUpperCase()}!'; // speak() guaranteed by `on Animal`
}
```

## Mixins: linearization order

`with A, B` applies mixins left-to-right, so **the rightmost mixin wins** for a
plain override, and `super` walks the chain right-to-left (top mixin → next → …
→ base). Order is therefore load-bearing.

```dart
mixin A { String who() => 'A'; }
mixin B { String who() => 'B'; }
class C with A, B {}   // C().who() == 'B' — rightmost wins

class Base { void step() => print('base'); }
mixin Double on Base { @override void step() { super.step(); print('x2'); } }
mixin Plus   on Base { @override void step() { super.step(); print('+1'); } }

class P extends Base with Double, Plus {}  // step(): base, x2, +1
class Q extends Base with Plus, Double {}  // step(): base, +1, x2  ← swapped!
```

`super` inside a mixin means "the next class to the left in the linearization,"
not the syntactic superclass — that's why reordering `with` changes the output.

## `mixin` vs `mixin class`

- `mixin M` — can **only** be mixed in with `with`; cannot be instantiated or
  extended, and cannot declare a generative constructor.
- `mixin class M` — usable **both** as a mixin (`with M`) and as a normal class
  (`extends M`, `M()`). It may only have a default/unnamed no-arg constructor and
  cannot have an `on` clause.

```dart
mixin class Counter {
  int count = 0;
  void inc() => count++;
}
class A extends Counter {}   // ok — used as a class
class B with Counter {}      // ok — used as a mixin
```

## Mixins have no constructors

A mixin is grafted onto many host classes, and the **host** owns construction, so
a (non-`mixin class`) mixin **cannot declare a constructor**. Initialize state via
field initializers (which run during the host's construction) or via abstract
getters the host must implement. Field initializers in a mixin **cannot reference
constructor parameters** — there are none.

```dart
mixin Timestamped {
  final DateTime createdAt = DateTime.now(); // initializer runs with the host
  String get label;                          // host must supply this
}
```

## Callable classes (`call`)

Define a `call` method and instances become invocable like functions and are
assignable to the matching `Function` type — handy for configurable, stateful
"functions" you can also equate/inspect.

```dart
class Adder {
  const Adder(this.by);
  final int by;
  int call(int x) => x + by;
}

const add2 = Adder(2);
add2(40);                       // 42 — instance invoked like a function
[1, 2, 3].map(add2).toList();   // assignable to int Function(int)
```

## Custom operators

Override operators with `operator <op>`. Overridable: `+ - * / ~/ % | ^ & << >> []
[]= ~ < > <= >= ==`. You **cannot** override `= && || ! ?. ??` or the ternary.

```dart
class Vec {
  const Vec(this.x, this.y);
  final double x, y;

  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);
  Vec operator *(double s) => Vec(x * s, y * s);
  double operator [](int i) => i == 0 ? x : y;   // []= is a separate operator

  @override
  bool operator ==(Object other) =>
      other is Vec && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);          // MUST pair with ==
}
```

- **`==` and `hashCode` travel together.** Overriding one without the other breaks
  `Set`/`Map` membership; the `hash_and_equals` lint flags it. For full value-type
  guidance (incl. `Object.hash`, freezed) see the `data-model` skill and
  `collections-and-generics.md`.
- `a == b` is special-cased for null: it returns `true`/`false` for null receivers
  without calling your `operator ==`, so your override never sees a null `this`.
- Define `[]=` separately for index assignment; `[]` alone gives read-only access.
