# Optimization anti-patterns: do / avoid

Most Flutter jank and memory growth comes from rebuilding too much and from
holding state in the wrong place. (Flutter 3.44 / Dart 3.12.)

Already covered elsewhere — cross-reference instead of repeating:
- **#5 / #11 controllers, subscriptions, timers, listeners** — create in
  `initState`, dispose/cancel/close/remove in `dispose`: read
  `reference/memory-and-leaks.md`.
- **#13 helper-method widgets** and **#27 missing `const`** — extract real
  `const StatelessWidget`s and prefer `const`: read
  `reference/rebuilds-and-const.md`.

## 3. `setState` misuse
Calling `setState` for every keystroke/tick, or on a state object that wraps a
big slice of UI, rebuilds far more than changed. Isolate the mutable bit in the
smallest possible widget; use a state-mgmt solution only for genuinely shared
state.

```dart
// Avoid: counter lives on the whole page → the entire page rebuilds on tap.
class ProductPage extends StatefulWidget {
  const ProductPage({super.key});
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  int _qty = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExpensiveHeader(),      // rebuilt every tap, for nothing
        const ProductGallery(),       // rebuilt every tap, for nothing
        Text('Qty: $_qty'),
        IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add)),
      ],
    );
  }
}

// Do: confine the changing state to its own small widget.
class ProductPage extends StatelessWidget {
  const ProductPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [ExpensiveHeader(), ProductGallery(), QuantityStepper()],
    );
  }
}

class QuantityStepper extends StatefulWidget {
  const QuantityStepper({super.key});
  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  int _qty = 0;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Qty: $_qty'),
        IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add)),
      ],
    );
  }
}
```

For state shared across siblings or screens, reach for Riverpod/Bloc/`provider`
rather than lifting `setState` up and rebuilding a whole subtree.

## 8. Whole-tree rebuilds for a local change
When the value lives on an ancestor but only one leaf reads it, `setState` on the
ancestor repaints everything. Use `ValueNotifier` + `ValueListenableBuilder`, or
a selector (`ref.watch(p.select(...))`, `Selector`, `buildWhen`) so only the
dependent widget rebuilds.

```dart
// Avoid: ancestor setState rebuilds the header, the list, and the footer.
class _DashboardState extends State<Dashboard> {
  int _badge = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeavyChart(),
        Text('$_badge'),                       // only this depends on _badge
        const HeavyFeed(),
      ],
    );
  }
}

// Do: hold the value in a ValueNotifier; rebuild only the badge.
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _badge = ValueNotifier<int>(0);
  @override
  void dispose() {
    _badge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeavyChart(),
        ValueListenableBuilder<int>(
          valueListenable: _badge,
          builder: (_, value, __) => Text('$value'),
        ),
        const HeavyFeed(),
      ],
    );
  }
}
```

## 7 & 26. Stateless vs Stateful: pick by mutability
Decision rule: **does anything change over this widget's lifetime?** If yes
(toggle, controller, animation, fetched data held locally) → `StatefulWidget`.
If no → `StatelessWidget`, which lets the constructor be `const` and short-circuit
rebuilds. Don't default to Stateful "just in case" — it forfeits `const`.

```dart
// Avoid: StatefulWidget with no mutable state — pure overhead, never const.
class PriceTag extends StatefulWidget {
  const PriceTag({required this.price, super.key});
  final double price;
  @override
  State<PriceTag> createState() => _PriceTagState();
}

class _PriceTagState extends State<PriceTag> {
  @override
  Widget build(BuildContext context) => Text('\$${widget.price}');
}

// Do: it only renders inputs → StatelessWidget, usable as `const PriceTag(...)`.
class PriceTag extends StatelessWidget {
  const PriceTag({required this.price, super.key});
  final double price;
  @override
  Widget build(BuildContext context) => Text('\$$price');
}
```

```dart
// Do: genuinely needs mutable state (a toggle) → Stateful is correct here.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key});
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _on = false;
  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(_on ? Icons.favorite : Icons.favorite_border),
        onPressed: () => setState(() => _on = !_on),
      );
}
```

## 12. Wrong scroll widget for long content
`SingleChildScrollView` + `Column` (or `Column(children: items.map(...).toList())`)
builds and lays out **every** child up front, even off-screen ones — O(n) work and
memory regardless of viewport. Use `ListView.builder` / `SliverList.builder`,
which build lazily as items scroll into view.

```dart
// Avoid: builds all 5,000 rows immediately, janky first frame, high memory.
SingleChildScrollView(
  child: Column(
    children: [for (final item in items) ProductRow(item: item)],
  ),
);

// Do: lazy — only visible rows (plus a small cache) are built.
ListView.builder(
  itemCount: items.length,
  itemExtent: 72, // fixed-height rows: skip per-item layout measurement
  itemBuilder: (context, i) => ProductRow(item: items[i]),
);

// Do: mixing scrollable sections → slivers stay lazy under one scroll view.
CustomScrollView(
  slivers: [
    const SliverAppBar(title: Text('Catalog')),
    SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => ProductRow(item: items[i]),
    ),
  ],
);
```

A `Column` inside a `SingleChildScrollView` is fine for a *small, bounded* set of
widgets (a form, a settings page). The anti-pattern is using it for many or
unbounded items.
