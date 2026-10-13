# Rebuilds, const, and extract-widget-vs-method

## const widgets cost (almost) nothing

A `const` widget is canonicalized once and **skips rebuild entirely** — Flutter reuses the same instance and short-circuits the subtree.

```dart
// before: rebuilt every parent rebuild
Padding(padding: EdgeInsets.all(8), child: Text('Title'))

// after: built once, reused forever
const Padding(padding: EdgeInsets.all(8), child: Text('Title'))
```

Make constructors `const` and pass `const` children wherever values are compile-time constants. The **analyze** skill enables `prefer_const_constructors` to enforce this automatically.

## Split widgets to localize rebuilds

When `setState`/state change rebuilds a widget, it rebuilds that widget's whole subtree. Extract the changing part into its own widget so the static parts stay untouched.

```dart
// before: typing rebuilds the entire page including the heavy chart
class _PageState extends State<Page> {
  String query = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(onChanged: (v) => setState(() => query = v)),
        ExpensiveChart(),          // rebuilds on every keystroke!
        Text('Search: $query'),
      ]);
}

// after: the chart is const/extracted; only the result line rebuilds
class _PageState extends State<Page> {
  String query = '';
  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(onChanged: (v) => setState(() => query = v)),
        const ExpensiveChart(),    // never rebuilds
        Text('Search: $query'),
      ]);
}
```

## Extract a widget, NOT a method that returns a Widget

This is the highest-leverage habit. A method called from `build()` reruns whenever the parent rebuilds and **cannot be `const`**. A separate widget class is its own rebuild boundary and can be `const`.

```dart
// avoid: helper method — reruns with the parent, never const
Widget _buildHeader() => Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
    );

// do: real widget — localizes rebuilds, can be const-constructed
class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
      );
}
// usage: const _Header()  — skipped on parent rebuild
```

Why it matters:
- The method's returned subtree is rebuilt on **every** parent build; the widget's `build` runs only when *its own* inputs change.
- Only a widget can be marked `const`, unlocking the canonicalization short-circuit.
- A widget gives DevTools a named rebuild boundary you can actually measure.

Use methods only for trivial, throwaway, non-`const` fragments.

## Keep build() pure and cheap

`build()` runs often. Do no allocation, parsing, or I/O in it.

```dart
// before: new Random, list, and formatter every build
@override
Widget build(BuildContext context) {
  final items = List.generate(100, (i) => Item(Random().nextInt(99)));   // allocates each frame
  final fmt = NumberFormat.currency();                                    // allocates each frame
  return ItemList(items, fmt);
}

// after: compute once (initState / memoized / state-management selector)
late final List<Item> items = _loadItems();
static final _fmt = NumberFormat.currency();
@override
Widget build(BuildContext context) => ItemList(items, _fmt);
```

## State management: rebuild only what changed

Broad `setState` rebuilds the whole `State`'s subtree. Use selective rebuilds: Riverpod `ref.watch(provider.select(...))`, `Consumer`/`Selector` (provider), or `BlocBuilder` with `buildWhen`. See the **riverpod** and **bloc** skills.

```dart
// rebuilds only when the name field changes, not the whole user
final name = ref.watch(userProvider.select((u) => u.name));
```
