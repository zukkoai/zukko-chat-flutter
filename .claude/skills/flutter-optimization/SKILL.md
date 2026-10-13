---
name: flutter-optimization
description: Optimizes Flutter rendering for smooth 60/120fps using const widgets, ListView.builder, and RepaintBoundary. Use when fixing jank, slow scrolling, excessive rebuilds, memory leaks, or sluggish UI.
---

You are a Flutter performance engineer who keeps frames under budget (16ms at 60fps, 8ms at 120fps) by minimizing rebuilds, repaints, and allocations, and who prevents memory leaks.

## When to use
- Diagnosing jank, dropped frames, slow scrolling, or excessive widget rebuilds.
- Hunting memory growth / leaks, or reviewing for `const`, list, and dispose hygiene.

## Frame budget
Each frame may **build** (run `build()`), **layout** (size/position), and **paint** (rasterize). Optimization = do less of each, and localize work so a small change touches a small part of the tree.

## Rebuilds and const
- **Prefer `const` widgets** — canonicalized once, reused, and they **short-circuit rebuilds** of their subtree. Make constructors `const` and pass `const` children wherever values are compile-time constants.
- **Extract a `StatelessWidget` with a `const` constructor, NOT a helper method that returns a `Widget`.**
  - *Avoid:* `_buildChart()` — reruns on every parent rebuild and can never be `const`.
  - *Do:* `const ExpensiveChart()` — a real widget localizes rebuilds and can be `const`.
- Keep `build()` pure and cheap: **no** allocation, parsing, or I/O inside it. Compute once (`initState`/memoized/state selector).
- Selective rebuilds: `ref.watch(p.select(...))` (riverpod), `Selector` (provider), `BlocBuilder` `buildWhen`.

## Lists and painting
- **`ListView.builder`/`SliverList.builder` for long lists** — never `Column(children: list.map(...).toList())`, which builds every child up front.
- Give stateful list items stable `Key`s; set `itemExtent` (or `prototypeItem`) for fixed-height rows, and tune `cacheExtent` to trade memory for fewer rebuilds at the scroll edges. For sliver **composition** (mixed scrollable sections) see the **layout** skill — don't duplicate it here.
- Wrap frequently-repainting subtrees (animation, spinner, video) in `RepaintBoundary` — sparingly; each is its own layer.
- Lighter containers: `SizedBox`/`ColoredBox`/`DecoratedBox` over `Container`; `FadeTransition`/`Transform` over animated `Opacity` (which forces an offscreen `saveLayer` — costly even under Impeller), and avoid clipping inside scrolling lists. Decode images at display size (`cacheWidth`/`cacheHeight`).

## Memory and leaks
Dart's GC is **generational + mark-and-sweep**; it **cannot collect objects still referenced**. A forgotten subscription, listener, or controller keeps its whole object graph alive — that is a leak. Always:
- **Dispose** controllers and `AnimationController`s in `dispose()`.
- **Cancel** `StreamSubscription`s and `Timer`s; **close** `StreamController`s.
- **Remove** listeners you added (`removeListener`, `ValueNotifier`, `Animation`).
- **Check `mounted`** after every `await` before `setState`/touching `context`; never store `BuildContext` in a long-lived object.
- Reduce allocations in `build()`. Profile heap growth with DevTools Memory view.

## Common mistakes
- `setState` for every tiny change / high in the tree → isolate state in the smallest widget; lift only shared state into a state-mgmt solution.
- `setState` on a large ancestor for a local change → push state down, or use `ValueListenableBuilder` / `select` so only the dependent leaf rebuilds.
- `StatefulWidget` with no mutable state → use `StatelessWidget` so the subtree can be `const`.
- `SingleChildScrollView` + `Column` for many/unbounded items → `ListView.builder` / slivers (lazy, builds only what's visible).
- Controllers/subscriptions/timers created in `build` or never released → create in `initState`, dispose/cancel/close in `dispose` (see `reference/memory-and-leaks.md`).
- `Widget _buildHeader()` helper → extract a real `const StatelessWidget` (see `reference/rebuilds-and-const.md`).
- Stateless vs Stateful confusion → state that changes over the widget's life ⇒ Stateful; otherwise Stateless. Missing `const` ⇒ see `reference/rebuilds-and-const.md`.

## Gotchas
- **`const` only short-circuits if the *whole* subtree is const** — a single non-const child cascades a rebuild up; one stray non-const node defeats it.
- **`RepaintBoundary` caches a subtree's layer so static content isn't re-rasterized** — use it to shield static neighbors from a busy island (animation/spinner/video). A subtree that itself changes *every frame* gets **no** cache reuse, just an extra layer + memory; each is its own layer, so don't sprinkle them.
- **Read the UI thread and raster thread separately** — in DevTools, Dart `build`/layout/paint-recording runs on the **UI thread**; Impeller rasterization runs on the **raster (GPU) thread**. Jank on each needs a different fix — see `reference/devtools.md`.
- **Profile in release/profile mode, not debug** — debug builds are unoptimized (assertions, no JIT inlining); jank numbers from debug are meaningless.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, UI updates, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- `const` + extract-widget-vs-method full examples, pure `build()`: read `reference/rebuilds-and-const.md`.
- `ListView.builder`, keys, `itemExtent`, `RepaintBoundary`, light containers, images: read `reference/lists-and-painting.md`.
- GC overview, dispose patterns, and the leak checklist: read `reference/memory-and-leaks.md`.
- Finding jank and leaks with DevTools + Impeller notes: read `reference/devtools.md`.
- Common rebuild/state/list anti-patterns with do/avoid code: read `reference/anti-patterns.md`.
