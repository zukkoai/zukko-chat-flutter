# Lists, painting, layers, and images

## Long lists: builders, never map + Column

`Column(children: list.map(...).toList())` builds **every** child up front. `ListView.builder`/`SliverList` build only what's visible (lazy).

```dart
// before: builds 10,000 widgets even if 8 are visible — janky scroll, high memory
SingleChildScrollView(child: Column(children: items.map((i) => Row(i)).toList()))

// after: builds on demand
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, i) => RowTile(item: items[i]),
)
// in a CustomScrollView, use SliverList.builder with the same itemBuilder shape
```

Add `Key`s to stateful list items so element/state stays attached to the right data when the list reorders or filters:

```dart
itemBuilder: (context, i) => RowTile(key: ValueKey(items[i].id), item: items[i]),
```

For fixed-height rows, set `itemExtent` (or `prototypeItem` when the height comes from a sample item) so the scroll engine computes offsets in O(1) without measuring each child. Tune `cacheExtent` to control how much off-screen content is pre-built — larger trades memory for fewer rebuilds at the scroll edges, smaller cuts memory.

For sliver **composition** — mixing app bars, grids, and lists under one `CustomScrollView` — see the **layout** skill; this skill covers list *performance*, that one covers sliver *structure*. Don't duplicate it here.

## RepaintBoundary for animated/expensive subtrees

Wrap a frequently repainting subtree (animation, progress, video) in `RepaintBoundary` so its repaints don't dirty the rest of the layer.

```dart
// the spinner repaints constantly; the boundary keeps it off the static layer
const RepaintBoundary(child: CircularProgressIndicator())
```

Use it around custom-painted or animated regions. Don't sprinkle it everywhere — each boundary is its own layer and costs memory; apply where a small region repaints far more often than its surroundings.

The cache only pays off at a boundary between a busy region and a **static** one. Wrapping a subtree where everything around it *also* repaints every frame caches nothing — no reuse, just an extra layer + memory. The win for an animated island is shielding its static neighbors, not caching the island itself.

## Choose the lightest container

| Need | Use | Avoid |
|------|-----|-------|
| Empty space / sizing | `const SizedBox(width: 8)` | `Container(width: 8)` |
| Solid color background | `ColoredBox` | `Container(color: ...)` |
| Decoration (border/radius) | `DecoratedBox` | `Container(decoration: ...)` |
| Rounded corners | `BorderRadius` in a `BoxDecoration` | wrapping in `ClipRRect` |

Overusing `Opacity` and `ClipRRect`/`ClipPath` forces offscreen compositing (an extra `saveLayer` pass) — costly **even under Impeller**, and worst inside scrolling lists where it recurs every frame. Prefer painting the effect directly: a fade as `FadeTransition`/`Transform` rather than animated `Opacity`, and `BoxDecoration(borderRadius: ...)` instead of clipping.

```dart
// before: forces a GPU composite every frame of the animation
Opacity(opacity: _animation.value, child: child)
// after: uses the render layer directly, no extra composite pass
FadeTransition(opacity: _animation, child: child)
```

## Images: decode at display size and cache

Decoding a 4000px image into a 200px box wastes memory and CPU. Use `cacheWidth`/`cacheHeight` (or `ResizeImage`) to decode at target resolution.

```dart
Image.network(
  url,
  cacheWidth: 200,          // decode at 200px, not full size
  fit: BoxFit.cover,
)
```

`Image.network` caches in memory by default; for disk caching of remote images use `cached_network_image`. Always size images and lists explicitly so layout doesn't thrash.
