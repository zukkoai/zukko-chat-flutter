---
name: layout
description: Fixes Flutter layout and framework-internals problems with the constraints model — constraints go down, sizes go up, parent sets position. Use for "RenderBox was not laid out", "vertical/horizontal viewport was given unbounded height/width", "Incorrect use of ParentDataWidget", RenderFlex overflow, or sizing that collapses to zero or blows up to infinity. Covers Row/Column/Flex with Expanded/Flexible/mainAxisSize, Stack/Positioned, intrinsic sizing (IntrinsicHeight/IntrinsicWidth), LayoutBuilder, and ListView/Column nested inside a Row/Column. Also the widget/element/render trees and BuildContext, ValueKey/LocalKey/GlobalKey correctness when list items reorder or lose their state, InheritedWidget/InheritedModel (didChangeDependencies, updateShouldNotify, dependOnInheritedWidgetOfExactType vs getInheritedWidgetOfExactType), and composing CustomScrollView slivers (SliverToBoxAdapter, SliverList/SliverGrid, SliverAppBar).
---

You are a Flutter layout and framework-internals expert. You reason in **constraints**, place state in the right tree, and fix `RenderBox`/`ParentData`/unbounded errors at the source instead of papering over them with magic `SizedBox`es.

## When to use
- Layout crashes/overflow: "RenderBox was not laid out", "given unbounded height/width", "Incorrect use of ParentDataWidget", yellow-black RenderFlex overflow stripes.
- Sizing puzzles: a child that collapses to zero or expands to infinity; `Expanded`/`Flexible`/`Stack`/`Positioned` not behaving; intrinsic sizing.
- Tree/identity questions: `BuildContext`, widget vs element vs render object, keys, `InheritedWidget`, composing a `CustomScrollView` from slivers.

## The one mental model
**Constraints go down, sizes go up, parent sets position.** Each parent passes a `BoxConstraints` (min/max width+height) **down**; the child picks its own size **within** that range and passes it back **up**; the parent then **positions** it. A child can never know its own size from inside `build` — only the constraint it was given (read it with `LayoutBuilder`). Errors almost always mean a constraint was **unbounded** (max = `infinity`) where a widget needed a finite bound.

## Unbounded constraints — the #1 generated-code crash
A scrollable (`ListView`, `GridView`, `SingleChildScrollView`, `CustomScrollView`) wants to be **infinitely tall** in its scroll axis. Put one in something that *also* gives unbounded height (a `Column`, another scroll view, unbounded `Stack`) and it cannot lay out.

```dart
// AVOID — ListView gets unbounded height inside Column → "RenderBox was not laid out"
Column(children: [const Header(), ListView(children: tiles)])

// DO — Expanded hands the ListView the remaining bounded height
Column(children: [const Header(), Expanded(child: ListView(children: tiles))])
```

Pick by intent: **`Expanded`** when the list should fill leftover space (the usual fix); **`SizedBox(height: n)`** for a fixed band; **`shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()`** only for a *short* inner list (it measures all children up front — never for long/lazy lists). Same crash with a `Row` + horizontal scrollable → use the same fixes on the cross axis. Full algorithm + every variant: `reference/constraints.md`.

## Flex: Expanded vs Flexible (the direct-child rule)
`Expanded`/`Flexible` are `ParentDataWidget`s — they only mean something to a `Row`/`Column`/`Flex` and **must be a direct child** of one. Wrap one in a `Container`/`Center`/`Stack` and you get **"Incorrect use of ParentDataWidget"**.

```dart
// AVOID — Expanded under a Container, not directly under the Row
Row(children: [Container(child: Expanded(child: Text(name)))])
// DO
Row(children: [Expanded(child: Container(child: Text(name)))])
```

- **`Expanded`** = `Flexible(fit: FlexFit.tight)` — *forces* the child to fill its share. **`Flexible`** (`fit: loose`, the default) lets the child stay smaller than its share. Use `flex:` to weight shares.
- **`mainAxisSize: MainAxisSize.min`** shrinks the Row/Column to its children (e.g. inside a `Wrap`/`Stack`); default `.max` expands to fill the main axis.

## Stack & Positioned
- A **`Positioned`** is also a `ParentDataWidget` — it must be a **direct child of a `Stack`** (same error otherwise).
- **Non-positioned** children are sized/placed by the Stack's `alignment` and `fit`; the Stack sizes itself to the **largest non-positioned child**. With only positioned children it can collapse — give it bounds (`SizedBox`, `Positioned.fill`, or `fit: StackFit.expand`).

## Intrinsic sizing is expensive
`IntrinsicHeight`/`IntrinsicWidth` (and "shrink-wrap then expand" patterns) force an extra measuring pass — roughly **O(N²)** down the subtree. Fine for a small static row; **never** per item in a scrolling list. Prefer fixed extents (`itemExtent`, `SizedBox`, `AspectRatio`) over intrinsics in lists.

## Keys — correctness, not performance
Keys preserve **element/State identity** when a widget's *position* among siblings changes. Omit a key on **reorderable stateful** children and Flutter matches old elements to new widgets by index — so `State` (scroll offset, controllers, animations, checkbox value) sticks to the **wrong row** or is lost.

```dart
// AVOID — index/UniqueKey: state hops rows on reorder, or is thrown away every build
itemBuilder: (c, i) => TodoTile(key: UniqueKey(), todo: todos[i]),
// DO — stable identity tied to the data
itemBuilder: (c, i) => TodoTile(key: ValueKey(todos[i].id), todo: todos[i]),
```

Stateless rows that never reorder need **no** key. Use a **`LocalKey`** (`ValueKey`/`ObjectKey`) within a sibling list; reserve **`GlobalKey`** for moving a widget across the tree or reaching its `State`/`context` — it's heavy, must be unique app-wide, and is **not** a fix for "use a key here". Details: `reference/keys-and-trees.md`.

## Three trees + BuildContext
**Widget** (immutable config) → **Element** (mutable instance, holds `State`, the actual node) → **RenderObject** (layout/paint). A **`BuildContext` *is* the `Element`** — it marks *where this widget sits in the element tree*, which is why `Theme.of(context)`/`MediaQuery.of(context)` look *upward* from that spot and why a stale or wrong-level context misreads. See `reference/keys-and-trees.md`.

## InheritedWidget (the O(1) propagation primitive)
`InheritedWidget` pushes data down so descendants read it in O(1) and **rebuild automatically** when it changes. The footguns:
- **Subscribe in `didChangeDependencies`, not `initState`** — `initState` runs before the inherited lookup is wired, and won't re-fire when the value changes.
- **`dependOnInheritedWidgetOfExactType`** registers the caller as a dependent (rebuilds on change); **`getInheritedWidgetOfExactType`** reads **without** subscribing (no rebuild) — using the wrong one is a top cause of "value changed but no rebuild".
- **`updateShouldNotify`** must return `true` exactly when dependents should rebuild (value `!=` old). Use **`InheritedModel`** for aspect-scoped rebuilds. For app-level state built *on top of* this, use `state-management`. Details: `reference/inherited-widget.md`.

## Slivers (composition)
`CustomScrollView.slivers` accepts **slivers only** — a plain box widget there throws. Wrap one box in **`SliverToBoxAdapter`** (or `SliverFillRemaining`); use **`SliverList`/`SliverGrid`** for lists, **`SliverAppBar`** (`pinned`/`floating`/`snap`) for collapsing headers, `NestedScrollView` to coordinate an outer header with inner tabs. Lazy-list **performance** (itemExtent, cacheExtent, builders) lives in `flutter-optimization` — don't duplicate it here. Patterns: `reference/slivers.md`.

## Footgun table
| Symptom / error | Cause | Fix |
|---|---|---|
| "RenderBox was not laid out" / "viewport given unbounded height" | scrollable/`Column` inside an unbounded parent | `Expanded`/`Flexible`/`SizedBox`; `shrinkWrap` only for short lists |
| "Incorrect use of ParentDataWidget" | `Expanded`/`Flexible`/`Positioned` not a direct child of `Flex`/`Stack` | move it to be the direct child |
| RenderFlex overflowed by N px | children exceed the main axis | `Expanded`/`Flexible`, `Wrap`, or scroll the axis |
| Row/Column collapses or fills the whole screen | wrong `mainAxisSize` | `.min` to hug, `.max` to fill |
| List item loses/swaps state on reorder | missing/unstable key | `ValueKey(item.id)` on the stateful item |
| `.of(context)` returns null / wrong value | context above the provider, or read in `initState` | read below the provider, in `didChangeDependencies` |

## Common mistakes
- `ListView`/`GridView`/`Column` inside a `Column`/`Row` with no `Expanded` → unbounded crash (see `reference/constraints.md`).
- `Expanded`/`Flexible`/`Positioned` wrapped in a `Container`/`Center` → ParentDataWidget error; make it the direct child.
- `IntrinsicHeight`/shrink-wrap per row in a long list → O(N²) layout; use fixed extents.
- `UniqueKey()` or index keys on reorderable stateful rows → state attaches to the wrong row (`reference/keys-and-trees.md`).
- Reading an `InheritedWidget` in `initState`, or with `getInheritedWidgetOfExactType`, then wondering why it never rebuilds.
- Putting a box widget directly in `CustomScrollView.slivers` instead of `SliverToBoxAdapter`.

## Gotchas
- **A child can't size itself from `build`** — it only knows its incoming constraints. Need the real size? `LayoutBuilder` (constraints pre-build) or `addPostFrameCallback` (geometry post-build); never a magic constant.
- **`double.infinity` width means "as wide as allowed", not a literal infinity** — harmless under a bounded parent, a crash under an unbounded one (e.g. inside a horizontal `ListView`).
- **`Spacer` is `Expanded`** under the hood — it dies outside a `Flex` and can't share space with another `Expanded` that wants it all.
- **`GlobalKey` is not a "make it work" key** — it forces an element to move/re-parent (re-running its subtree) and must be unique; misuse causes duplicate-key crashes.
- **`shrinkWrap: true` is not free** — it lays out every child to measure the list, defeating laziness; only for genuinely short inner lists.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (`flutter analyze` clean, no overflow/unbounded errors in the console, list-item state survives reorder).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Constraint algorithm, `BoxConstraints`, unbounded errors, Flex/`Expanded`/`Flexible`, Stack/`Positioned`, intrinsic sizing, `LayoutBuilder`: read `reference/constraints.md`.
- `CustomScrollView`, sliver types, `SliverAppBar`, `SliverToBoxAdapter`, `NestedScrollView` (perf lives in `flutter-optimization`): read `reference/slivers.md`.
- Widget/Element/RenderObject trees, element lifecycle, `BuildContext`, `LocalKey`/`ValueKey`/`GlobalKey`, when keys matter: read `reference/keys-and-trees.md`.
- `InheritedWidget`/`InheritedModel`, `didChangeDependencies`, `updateShouldNotify`, subscribe vs read (cross-link `state-management`): read `reference/inherited-widget.md`.
- Related: `flutter-optimization` (rebuild/scroll perf), `state-management` (app state on top of InheritedWidget), `responsive` (adaptive breakpoints via `LayoutBuilder`/`MediaQuery`).
