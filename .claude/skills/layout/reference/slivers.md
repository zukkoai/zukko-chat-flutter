# Slivers and CustomScrollView (composition)

- [What a sliver is](#what-a-sliver-is)
- [CustomScrollView: slivers only](#customscrollview-slivers-only)
- [The sliver toolbox](#the-sliver-toolbox)
- [SliverAppBar: pinned / floating / snap](#sliverappbar-pinned--floating--snap)
- [NestedScrollView](#nestedscrollview)
- [Performance lives elsewhere](#performance-lives-elsewhere)

This file is about **composing** a scroll view out of slivers. Scroll **performance** (itemExtent, cacheExtent, lazy builders) is owned by `flutter-optimization` — cross-linked below, not duplicated here.

## What a sliver is

A **sliver** is a scrollable region that knows how to lay itself out against a `SliverConstraints` (scroll offset, remaining paint extent, viewport size) and report a `SliverGeometry` back. Regular widgets (`Container`, `Text`, `Card`) are **boxes** — they speak `BoxConstraints`, not sliver protocol. The two protocols don't mix directly, which is why you can't drop a box straight into a sliver list.

Use a `CustomScrollView` (instead of stacking `ListView` + `GridView` + headers) when you need **multiple scrollable sections sharing one scroll position and one viewport** — e.g. a collapsing app bar over a grid over a list.

## CustomScrollView: slivers only

`CustomScrollView.slivers` accepts **slivers exclusively**. A plain box widget there throws (`"A RenderViewport expected a child of type RenderSliver"`). Wrap boxes in an adapter:

```dart
// AVOID — Text is a box, not a sliver
CustomScrollView(slivers: [const Text('Header'), SliverList(...)])

// DO — adapt the box into the sliver world
CustomScrollView(
  slivers: [
    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('Header'))),
    SliverList.builder(itemCount: n, itemBuilder: (c, i) => Tile(item: items[i])),
  ],
)
```

## The sliver toolbox

| Sliver | Use for |
|---|---|
| `SliverToBoxAdapter` | a single box widget (header, banner, divider) |
| `SliverList` / `SliverList.builder` | a lazy vertical list of items |
| `SliverGrid` / `SliverGrid.builder` | a lazy grid (`SliverGridDelegateWithFixedCrossAxisCount`/`MaxCrossAxisExtent`) |
| `SliverFixedExtentList` | a list whose rows all share one height (faster offsets) |
| `SliverPadding` | padding around another sliver (don't wrap a sliver in box `Padding`) |
| `SliverFillRemaining` | fill the leftover viewport (empty states, last page) |
| `SliverFillViewport` | one full-viewport page per child (pager feel) |
| `SliverAppBar` | collapsing/pinned header (see below) |
| `SliverPersistentHeader` | a custom header that pins or floats with a delegate |
| `SliverMainAxisGroup` / `SliverCrossAxisGroup` | compose slivers along/across the axis |

Wrap a sliver's spacing in **`SliverPadding`**, not a box `Padding` (which would re-introduce the box/sliver mismatch).

## SliverAppBar: pinned / floating / snap

```dart
CustomScrollView(
  slivers: [
    SliverAppBar(
      pinned: true,        // toolbar stays visible when collapsed
      floating: false,     // true → reappears on any upward scroll
      snap: false,         // true (needs floating) → snaps fully open/closed
      expandedHeight: 200,
      flexibleSpace: const FlexibleSpaceBar(title: Text('Gallery')),
    ),
    SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemBuilder: (c, i) => Image.network(urls[i], fit: BoxFit.cover),
      itemCount: urls.length,
    ),
  ],
)
```

- **`pinned`** keeps the collapsed bar on screen; **`floating`** lets it slide back in on scroll-up; **`snap: true`** requires `floating: true`.
- `expandedHeight` + `flexibleSpace`/`FlexibleSpaceBar` create the collapse effect; `collapsedHeight` sets the minimum.

## NestedScrollView

Use when an **outer** header (e.g. a `SliverAppBar` with tabs) must coordinate with **inner** scrollables (a `TabBarView` of lists) so the header collapses as either tab scrolls.

```dart
NestedScrollView(
  headerSliverBuilder: (context, innerBoxIsScrolled) => [
    SliverAppBar(pinned: true, bottom: TabBar(tabs: tabs)),
  ],
  body: TabBarView(children: [ListA(), ListB()]),
)
```

Wrap each inner list in a `Builder` + `CustomScrollView` with a `SliverOverlapAbsorber`/`SliverOverlapInjector` when the pinned header overlaps inner content (the standard tabs-under-app-bar recipe).

## Performance lives elsewhere

Choosing slivers is **composition**; making them scroll smoothly is **performance** and belongs to `flutter-optimization`:

- Always use the **`.builder`** constructors for long lists (lazy).
- Set **`itemExtent`** / use `SliverFixedExtentList` for fixed-height rows (O(1) offsets, no per-child measure).
- Tune **`cacheExtent`**, wrap animated regions in `RepaintBoundary`, keep item builders cheap.

See `flutter-optimization` for those. For constraint/unbounded errors around a `CustomScrollView`, see `reference/constraints.md`.
