# Collections & generics — laziness, identity, variance

The footguns that bite in production. Collection literals / spread / collection-if
/ collection-for are covered in `naming-and-style.md` — only the non-obvious bits
are repeated here.

## Contents
- [Iterable laziness](#iterable-laziness)
- [Growable vs fixed-length lists](#growable-vs-fixed-length-lists)
- [The empty-literal trap](#the-empty-literal-trap)
- [Equality & identity in collections](#equality--identity-in-collections)
- [Mutating a key corrupts the bucket](#mutating-a-key-corrupts-the-bucket)
- [Insertion order & const collections](#insertion-order--const-collections)
- [Generics are covariant — the soundness hole](#generics-are-covariant--the-soundness-hole)
- [`covariant` for parameter narrowing](#covariant-for-parameter-narrowing)
- [Bounds, raw generics, `Object?` vs `dynamic`](#bounds-raw-generics-object-vs-dynamic)

## Iterable laziness

`map`, `where`, `expand`, `take`, `skip`, `followedBy` and `sync*` generators
return **lazy views**, not materialized collections. Nothing runs until you
iterate — and the **whole chain re-runs on every iteration**. Each `.length`,
`.first`, `.contains`, or `for` loop walks the pipeline again, so side effects
fire repeatedly and per-element work is duplicated.

```dart
// Avoid: a lazy chain re-evaluated by every terminal operation
final ids = users.where((u) => u.active).map((u) {
  log('mapping ${u.id}');   // side effect — runs again on each pass!
  return u.id;
});
ids.length;            // walks the chain + logs
ids.first;             // walks it AGAIN + logs again
for (final _ in ids) {} // and AGAIN

// Do: materialize once, then read freely
final ids = [
  for (final u in users) if (u.active) u.id,   // or .where(...).map(...).toList()
];
```

Materialize with `.toList()` / `.toSet()` the moment you iterate more than once,
pass the result around, or the source can change underneath the view.

## Growable vs fixed-length lists

`List.filled` is **fixed-length by default** — `.add()`/`.removeLast()` throw.
`List.generate` and list literals are growable. Copy with `List.of`; freeze with
`List.unmodifiable`.

```dart
final fixed  = List.filled(3, 0);            // fixed — .add() throws UnsupportedError
final grow   = List.filled(3, 0, growable: true);
final gen    = List.generate(3, (i) => i);   // growable
final copy   = List.of(fixed);               // growable copy
final frozen = List.unmodifiable(grow);      // .add()/[]= throw
```

## The empty-literal trap

An empty `{}` is a **`Map`, never a `Set`** — there is no element to infer from.
Always type empty set/map literals explicitly.

```dart
final x = {};               // Map<dynamic, dynamic>  ← NOT a Set
final s = <String>{};       // Set<String>
final m = <String, int>{};  // Map<String, int>
```

## Equality & identity in collections

`List`/`Map`/`Set` and their lookups use the element's `==`/`hashCode`. Custom
classes default to **identity** equality, so value-equal-but-distinct instances
count as different — `Set` keeps duplicates and `Map`/`contains` lookups miss.

```dart
class Point { Point(this.x, this.y); final int x, y; } // no ==/hashCode

final set = {Point(1, 2), Point(1, 2)};  // length 2 — treated as distinct
set.contains(Point(1, 2));               // false — lookup miss
```

Override `==` **and** `hashCode` together (or use freezed / a value-type) — see the
`data-model` skill and `operator ==` in `extensions-and-mixins.md`.

## Mutating a key corrupts the bucket

Even with correct `==`/`hashCode`, **mutating an object after using it as a `Map`
key or `Set` element** changes its `hashCode`, so it lands in the wrong bucket and
becomes unreachable. Use immutable keys.

```dart
// Avoid: a mutable object used as a key
final scores = <Team, int>{};   // Team overrides ==/hashCode over a mutable `name`
final t = Team(name: 'A');
scores[t] = 10;
t.name = 'B';                   // hashCode changed
scores[t];                     // null — the entry is now stranded
```

## Insertion order & const collections

- A `Map`/`Set` literal is a `LinkedHashMap`/`LinkedHashSet`: iteration follows
  **insertion order**, not key order. Use `SplayTreeMap` for sorted iteration.
- `const` collections are canonicalized, deeply immutable, and deduplicated at
  compile time. Keys/elements must themselves be constants.

```dart
const codes = {200, 200, 404};  // const Set → {200, 404}, unmodifiable
final m = {'b': 1, 'a': 2};     // iterates b, a (insertion order)
```

## Generics are covariant — the soundness hole

Dart generics are **covariant**: `List<int>` is a subtype of `List<num>`. Reading
is always safe; **writing through the widened type is not**, and Dart inserts a
runtime check that can throw. This is the classic surprise.

```dart
// Avoid: aliasing a List<int> as List<num> then writing a non-int
final ints = <int>[1, 2];
final List<num> nums = ints;   // allowed — covariance
nums.add(3.14);                // compiles; throws TypeError at RUNTIME (it's really List<int>)
```

Treat widened collections as read-only, or copy (`List<num>.of(ints)`) before
writing.

## `covariant` for parameter narrowing

By default you can't override a method with a **narrower** parameter type — it
would be unsound. The `covariant` keyword opts in, telling Dart to insert a
runtime type check at the call site (reintroducing the hole above, deliberately).

```dart
class Animal {}
class Cat extends Animal {}

class Shelter {
  void intake(covariant Animal a) {}
}
class CatShelter extends Shelter {
  @override
  void intake(Cat a) {}   // legal because the base param is `covariant`
}
```

## Bounds, raw generics, `Object?` vs `dynamic`

Bound type parameters to use the bound's members; never write raw generics or reach
for `dynamic` to dodge typing.

```dart
// Do: a bound gives access to Comparable members
T maxOf<T extends Comparable<T>>(T a, T b) => a.compareTo(b) >= 0 ? a : b;

// Avoid: raw generic erases the element type → returns dynamic
List parse(String s) => jsonDecode(s);     // List == List<dynamic>
// Do
List<Map<String, Object?>> parse(String s) =>
    (jsonDecode(s) as List).cast();
```

`Object?` vs `dynamic` look similar but differ in safety:

```dart
Object? a = fetch();   // top type — static checking ON
a.length;              // COMPILE ERROR — must test/cast first (e.g. if (a is String) a.length)

dynamic b = fetch();   // static checking OFF
b.length;              // compiles; NoSuchMethodError at runtime if absent
```

Prefer `Object?` for "anything" and narrow with `is`/`as`; reserve `dynamic` for
genuine interop where you accept losing all static checks.
