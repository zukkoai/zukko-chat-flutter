# Finding jank and leaks with DevTools (+ Impeller)

## DevTools views

| DevTools view | Use it to |
|---------------|-----------|
| Performance / Timeline | See per-frame build/layout/raster times; red bars = dropped frames. |
| "Track widget rebuilds" / Rebuild stats | Find widgets rebuilding too often — the targets for `const`/splitting. |
| CPU profiler | Spot expensive methods called during build. |
| Memory view | Watch heap growth and find leaks (objects never freed after disposal). |

Toggle "Highlight repaints" to see which layers repaint each frame — flashing static areas signal a missing `RepaintBoundary` or a too-broad rebuild.

## Workflow

1. Reproduce the jank/growth while recording in the relevant view.
2. **Jank:** in the Timeline, see **which thread** is over budget (UI vs raster — see below). Long **UI thread** (Dart build/layout) → too many/expensive rebuilds → `const` + widget extraction + selective rebuilds. Long **raster thread** (Impeller rasterization) → too many layers/overdraw → fewer `Opacity`/`saveLayer`/clips, add targeted `RepaintBoundary`.
3. **Rebuilds:** use rebuild stats to find the widget rebuilding far more than its data changes; extract it or add a selector.
4. **Memory:** snapshot the heap, exercise the screen, snapshot again. Objects that keep accumulating across navigations are leaks — trace their retaining path back to the missing `dispose`/`cancel`/`removeListener`.

## Profile correctly

- Profile on a **physical device in profile mode** (`flutter run --profile`). Debug mode and emulators are **not** representative — debug carries asserts and no JIT optimization; emulators have different GPUs.

## UI thread vs raster (GPU) thread

The Timeline has two thread tracks — read them **separately**, because jank on each has a different cause and fix:

- **UI thread** runs Dart: `build()`, layout, and paint *recording*. Long UI frames ⇒ too many/expensive rebuilds or layout → `const`, widget extraction, selective rebuilds, lazy lists.
- **Raster (GPU) thread** runs Impeller, turning the recorded display list into pixels. Long raster frames ⇒ too many layers / overdraw / expensive effects → cut `Opacity`/`saveLayer`/clips, add targeted `RepaintBoundary`.

A frame janks if *either* thread blows the budget; fixing the wrong thread changes nothing.

## Impeller notes

- Impeller is the **default renderer since Flutter 3.27** (iOS + Android API 29+); iOS has **no Skia opt-out** (Skia was removed on iOS ~3.29). **macOS** Impeller is opt-in; **web** does not use Impeller at all (CanvasKit/Skia).
- Impeller **compiles shaders ahead-of-time at build**, so the classic "first-run shader jank" is gone. SkSL shader warmup — `flutter run --bundle-sksl-path` / `--cache-sksl` — is **obsolete under Impeller** (Skia-legacy; relevant only on the web/legacy-Skia path). Do **not** ship those workarounds.
- The optimizations elsewhere in this skill (const, lazy lists, fewer layers, sized images, dispose hygiene) are renderer-agnostic and still apply under Impeller.

## Full optimization checklist

- [ ] `const` on every eligible widget; static subtrees extracted as `const` widgets (not methods).
- [ ] No allocation/logic/I/O inside `build()`.
- [ ] Long/lazy lists use `ListView.builder`/`SliverList`, never `map` + `Column`.
- [ ] Stateful list items have stable `Key`s; fixed-height lists set `itemExtent`.
- [ ] `RepaintBoundary` around frequently animated/painted subtrees only.
- [ ] `SizedBox`/`ColoredBox`/`DecoratedBox` over `Container`; `FadeTransition` over `Opacity`.
- [ ] Images decoded at display size (`cacheWidth`/`cacheHeight`).
- [ ] Controllers/animations disposed, streams cancelled, listeners removed, `mounted` checked post-`await`.
- [ ] Selective rebuilds via state-management selectors.
- [ ] Profiled on a physical device in profile mode with DevTools.
