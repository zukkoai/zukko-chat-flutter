# Constraints, Flex, Stack, and intrinsic sizing

- [The layout algorithm](#the-layout-algorithm)
- [BoxConstraints](#boxconstraints)
- [Unbounded constraints (the crashes)](#unbounded-constraints-the-crashes)
- [Flex: Row / Column / Expanded / Flexible](#flex-row--column--expanded--flexible)
- [RenderFlex overflow](#renderflex-overflow)
- [Stack and Positioned](#stack-and-positioned)
- [Intrinsic sizing (and why it's slow)](#intrinsic-sizing-and-why-its-slow)
- [LayoutBuilder: reading the constraint](#layoutbuilder-reading-the-constraint)

## The layout algorithm

**Constraints go down, sizes go up, parent sets position.** One single-pass walk:

1. A widget receives a `BoxConstraints` (min/max width and height) from its parent.
2. It passes constraints to its children (often modified).
3. Each child sizes itself **within** the constraints it got and reports its size up.
4. The parent positions each child (sets its `Offset`) and reports **its own** size up.

Consequences that explain most bugs:

- **A widget cannot pick a size outside its constraints.** `width: 10` under `minWidth: 100` still renders 100. The parent wins on bounds.
- **A widget cannot know its own size during `build`** — only its incoming constraints. To react to size, use `LayoutBuilder`.
- **Layout is one pass** (no negotiation) — which is why `IntrinsicHeight`/`Width`, which need a *speculative* extra pass, are expensive.

## BoxConstraints

Four numbers: `minWidth`, `maxWidth`, `minHeight`, `maxHeight`. Three shapes:

| Shape | Meaning | Example source |
|---|---|---|
| **Tight** | min == max — exactly one size | `SizedBox(width:, height:)`, screen for root |
| **Loose** | min == 0, max finite — "up to" | `Center`, `Align`, `Padding` content |
| **Unbounded** | max == `double.infinity` | scroll view's child, `Column` cross→ no, main→ children |

`BoxConstraints.tight(size)`, `.loose(size)`, `.expand()`. `Center`/`Align` **loosen** incoming constraints (so a child can be smaller); `SizedBox.expand` / `ConstrainedBox` **tighten** or clamp them. Knowing whether your child got tight or loose constraints explains "why is it full-width / why did it shrink to zero".

## Unbounded constraints (the crashes)

A widget that has **no intrinsic size** and is handed an **unbounded** max on the axis it needs to fill cannot decide a size → assertion failure.

- **Scroll views** (`ListView`, `GridView`, `SingleChildScrollView`, `CustomScrollView`) try to be infinite on their scroll axis. Under a `Column` (which gives children unbounded **vertical** space) → `"Vertical viewport was given unbounded height"` / `"RenderBox was not laid out"`.
- A `Column`/flex child sized `double.infinity` under an unbounded parent → same family of error.

```dart
// AVOID — first CRASHES (unbounded scrollable); second only OVERFLOWS (yellow/black stripes)
Column(children: [Header(), ListView(children: rows)])  // "RenderBox was not laid out" — unbounded height
Column(children: [Header(), Column(children: rows)])    // no crash; overflows if rows exceed the height

// DO — give the scrollable a bounded slot
Column(children: [Header(), Expanded(child: ListView(children: rows))])
Column(children: [Header(), SizedBox(height: 240, child: ListView(children: rows))])

// DO (short inner list only) — measure all children, no inner scroll
Column(children: [
  Header(),
  ListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: rows),
])
```

Trade-offs: **`Expanded`** = lazy + scrollable, fills leftover (default choice). **`SizedBox`** = fixed band. **`shrinkWrap`** = builds **every** child up front (no laziness) and still can't nest two scrollables on one axis cleanly — short lists only. The same logic applies on the horizontal axis inside a `Row`.

A nested scroll on the **same axis** (e.g. a vertical `ListView` inside a vertical `SingleChildScrollView`) is the other classic: collapse to one scroll view + slivers, or bound the inner one.

## Flex: Row / Column / Expanded / Flexible

`Row`/`Column`/`Flex` lay out children along a main axis:

1. Lay out **inflexible** children with loose constraints; sum their main-axis sizes.
2. Divide the **remaining** space among **flexible** children by `flex` weight.
3. `Expanded` children get **tight** constraints (must fill their share); `Flexible` get **loose** (may be smaller).

```dart
Row(children: [
  Expanded(flex: 2, child: A()),   // 2/3 of free space, forced to fill
  Flexible(flex: 1, child: B()),   // up to 1/3, may be narrower
])
```

- **`Expanded` == `Flexible(fit: FlexFit.tight)`.** Use `Flexible` (loose) when the child should keep its natural size up to its share (e.g. text that may be short).
- **`mainAxisSize`**: `.max` (default) makes the flex fill the main axis; `.min` makes it hug its children — required inside a `Wrap`, a `Stack` child, or a bottom sheet that should be content-height.
- **`crossAxisAlignment.stretch`** gives children tight cross-axis constraints (full width in a Column); the default `.center` leaves them loose.
- **`Spacer`** is `Expanded(child: SizedBox.shrink())` — it eats free space and therefore competes with other `Expanded`s.

Rule: `Expanded`/`Flexible`/`Spacer` must be a **direct child** of the `Flex`. Wrapping in `Container`/`Center`/`Padding` → **"Incorrect use of ParentDataWidget"**. Put the wrapper *inside* the `Expanded`.

## RenderFlex overflow

Yellow-black stripes + "RenderFlex overflowed by N pixels" mean children's combined main-axis size exceeds the flex's bounds (common: long text in a `Row`, a `Column` taller than the screen).

```dart
// AVOID — long text overflows the Row
Row(children: [Icon(Icons.tag), Text(veryLongLabel)])
// DO — let it take the leftover and ellipsize
Row(children: [const Icon(Icons.tag), Expanded(child: Text(veryLongLabel, overflow: TextOverflow.ellipsis))])
```

Other fixes: `Wrap` (flow to next line), make the axis scrollable, or `FittedBox` to scale down. Overflow is a **layout bug, not a styling choice** — don't hide it behind `ClipRect`.

## Stack and Positioned

`Stack` paints children in order; size and placement depend on whether a child is positioned.

- **Positioned children** (`Positioned`, `Positioned.fill`) are placed by their `top/right/bottom/left/width/height`. `Positioned` is a `ParentDataWidget` → must be a **direct child of `Stack`**.
- **Non-positioned children** are sized by the Stack's `fit` and aligned by `alignment` (default `topStart`). The **Stack sizes itself to its largest non-positioned child**.
- A Stack with **only positioned children** has nothing to size against → it can collapse. Give it bounds: a non-positioned sizing child, `SizedBox`, wrap a child in `Positioned.fill`, or `fit: StackFit.expand` (tightens non-positioned children to the Stack's size).

```dart
SizedBox(
  height: 200,
  child: Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Colors.black12),       // sizing child
      Positioned(right: 8, bottom: 8, child: FloatingActionButton(onPressed: () {})),
    ],
  ),
)
```

## Intrinsic sizing (and why it's slow)

`IntrinsicHeight`/`IntrinsicWidth` ask children "what's your natural min/max size?" before the real layout pass — a **second walk** of the subtree. Cost compounds with nesting toward **O(N²)**.

- Legitimate, rare uses: making `Row` children share the **tallest** sibling's height; equalizing button widths in a small static group.
- **Never** wrap list rows in `IntrinsicHeight`, and avoid intrinsics inside scrollables. Prefer fixed sizing: `SizedBox`, `AspectRatio`, `itemExtent`, or a `Table` with fixed column widths.

```dart
// AVOID — quadratic per row in a long list
ListView.builder(itemBuilder: (c, i) => IntrinsicHeight(child: Row(children: cells(i))));
// DO — fixed extent, O(1) offset math
ListView.builder(itemExtent: 72, itemBuilder: (c, i) => Row(children: cells(i)));
```

## LayoutBuilder: reading the constraint

When a widget must decide based on the space it's actually given, `LayoutBuilder` exposes the incoming `BoxConstraints` (resolved before paint).

```dart
LayoutBuilder(
  builder: (context, constraints) => constraints.maxWidth > 600
      ? const TwoPaneLayout()
      : const SinglePaneLayout(),
)
```

- It rebuilds when the **constraints** change (resize, rotate, parent reflow) — ideal for adaptive layout (see `responsive`).
- It reports the **constraint**, not a final size; place it where the parent actually bounds it. For post-layout geometry of a specific box, use a `GlobalKey` + `RenderBox` in a post-frame callback instead.
