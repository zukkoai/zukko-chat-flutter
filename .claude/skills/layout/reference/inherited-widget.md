# InheritedWidget and InheritedModel

- [What it is](#what-it-is)
- [A minimal InheritedWidget](#a-minimal-inheritedwidget)
- [Subscribe vs read: the two lookups](#subscribe-vs-read-the-two-lookups)
- [didChangeDependencies, not initState](#didchangedependencies-not-initstate)
- [updateShouldNotify correctness](#updateshouldnotify-correctness)
- [InheritedModel: aspect-scoped rebuilds](#inheritedmodel-aspect-scoped-rebuilds)
- [When to reach for state-management instead](#when-to-reach-for-state-management-instead)

## What it is

`InheritedWidget` is the framework primitive that propagates data **down** the tree and rebuilds **only the descendants that depend on it** when it changes. Lookups are **O(1)**: each `BuildContext` caches a map of inherited ancestors by type, so `dependOnInheritedWidgetOfExactType` is a hash lookup, not a tree walk. `Theme`, `MediaQuery`, `DefaultTextStyle`, and every `provider`/Riverpod `Scope` are built on it.

## A minimal InheritedWidget

```dart
class CartScope extends InheritedWidget {
  const CartScope({super.key, required this.cart, required super.child});

  final Cart cart;

  static CartScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope.of() called with no CartScope above');
    return scope!;
  }

  @override
  bool updateShouldNotify(CartScope oldWidget) => cart != oldWidget.cart;
}
```

Read it with `CartScope.of(context).cart`. To **change** the value, an ancestor `StatefulWidget` rebuilds and supplies a new `cart` into a new `CartScope` instance.

## Subscribe vs read: the two lookups

Two methods, very different behavior — mixing them up is the top cause of "the value changed but nothing rebuilt":

| Method | Registers dependency? | Rebuilds caller on change? | Use when |
|---|---|---|---|
| `dependOnInheritedWidgetOfExactType<T>()` | **yes** | **yes** | normal reads in `build`/`didChangeDependencies` |
| `getInheritedWidgetOfExactType<T>()` | no | no | one-off read where you must **not** subscribe (e.g. inside `dispose`, or a callback firing after change) |

```dart
// AVOID — getInherited... does NOT subscribe; UI keeps showing the old value
Widget build(BuildContext context) {
  final cart = context.getInheritedWidgetOfExactType<CartScope>()!.cart; // never rebuilds
  return Text('${cart.count}');
}
// DO — dependOn... subscribes; rebuilds when updateShouldNotify returns true
Widget build(BuildContext context) {
  final cart = CartScope.of(context).cart;
  return Text('${cart.count}');
}
```

## didChangeDependencies, not initState

A `State` that needs an inherited value must read it in **`didChangeDependencies`**, not `initState`:

- `initState` runs **before** the element's inherited dependencies are wired — calling `dependOnInheritedWidgetOfExactType` there asserts/misses, and it **never re-fires** when the value later changes.
- `didChangeDependencies` runs **right after** `initState` *and again every time a subscribed inherited ancestor changes* — the correct hook to (re)create anything derived from inherited data (a subscription to that value, a controller seeded from it).

```dart
// AVOID — read in initState: too early, and stale forever after
@override
void initState() {
  super.initState();
  _locale = Localizations.localeOf(context); // wrong: not wired yet, won't update
}
// DO — read in didChangeDependencies: correct timing, refreshes on change
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _locale = Localizations.localeOf(context);
}
```

(Reading inherited data directly in `build` is also fine and re-runs on change; use `didChangeDependencies` when you need to do *work* in response, not just read.)

## updateShouldNotify correctness

`updateShouldNotify(old)` decides whether dependents rebuild when the `InheritedWidget` itself is rebuilt. Get it wrong in either direction:

- **Always `true`** → every ancestor rebuild rebuilds all dependents even when the data is identical (wasted frames).
- **Always `false`** (or comparing the wrong field) → real changes are invisible; the UI goes stale.

Return `true` exactly when the carried value changed: `return data != oldWidget.data;`. This needs **real value equality** — if `data` is a custom class, give it `==`/`hashCode` (or `Equatable`/`freezed`); otherwise two equal-looking instances compare unequal and you rebuild constantly. If you pass a `List`/`Map`, hand in a **new collection** on change (same identity → compares equal → no rebuild), mirroring the `state-management` rebuild rule.

## InheritedModel: aspect-scoped rebuilds

`InheritedModel<T>` lets dependents subscribe to a **specific aspect** so a change to one field doesn't rebuild widgets that only care about another.

```dart
class Settings extends InheritedModel<String> {
  const Settings({super.key, required this.theme, required this.locale, required super.child});
  final ThemeMode theme;
  final Locale locale;

  static Settings of(BuildContext c, String aspect) =>
      InheritedModel.inheritFrom<Settings>(c, aspect: aspect)!;

  @override
  bool updateShouldNotify(Settings old) => theme != old.theme || locale != old.locale;

  @override
  bool updateShouldNotifyDependent(Settings old, Set<String> aspects) =>
      (aspects.contains('theme') && theme != old.theme) ||
      (aspects.contains('locale') && locale != old.locale);
}
```

A widget reading `Settings.of(context, 'theme')` rebuilds only when `theme` changes, not `locale`.

## When to reach for state-management instead

`InheritedWidget` is the **mechanism**; for app features you usually want a package built on top of it:

- Manual `InheritedWidget` is fine for small, read-mostly scoped values (a theme token, a feature flag, a controller handle).
- For mutable app/feature state, async loading, derived state, and DI, use **`state-management`** (Riverpod/Bloc) — it wraps this primitive with ergonomics and correct rebuild semantics so you don't hand-roll `updateShouldNotify`.
- For *why a dependent didn't rebuild*, check this file's subscribe-vs-read and `updateShouldNotify` sections; for *why a list item rebuilt wrong*, see `reference/keys-and-trees.md`.
