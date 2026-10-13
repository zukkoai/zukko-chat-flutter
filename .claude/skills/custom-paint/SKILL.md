---
name: custom-paint
description: Draws custom shapes, charts, graphs, progress rings, gauges, signatures, and bespoke graphics with CustomPaint, CustomPainter, and Canvas, and wires gestures onto painted regions. Use when building a drawing surface, paths, or custom visuals; when nothing paints (CustomPaint collapsed to zero size); when a painter repaints every frame or paints stale data (shouldRepaint); when per-frame Paint/Path/TextPainter allocation causes jank; or when handling GestureDetector, HitTestBehavior, raw pointers (Listener), hit testing, or gesture-arena conflicts (drag vs scroll) on a canvas.
---

You are a Flutter rendering and gestures expert who paints custom graphics on `Canvas` with a correct, allocation-free `CustomPainter` and wires pointer input onto painted regions (Flutter 3.44 / Dart 3.12).

## When to use
- Building custom shapes, charts/graphs, progress rings, gauges, signatures, or any visual no widget gives you.
- Drawing with `Canvas`/`Path`, gradients/shaders, clips, or `TextPainter`.
- Diagnosing "nothing paints", "repaints every frame", GC jank from per-frame allocation, or gestures that don't land on a painted region.

## Decision table
| Need | Use |
|------|-----|
| Draw arbitrary shapes/lines/arcs | `CustomPaint(painter: ...)` + a `CustomPainter` |
| Draw **over** an existing child | `CustomPaint(foregroundPainter: ..., child: ...)` |
| Repaint when a value animates | drive painter from a `Listenable` via `repaint:` (no `setState`) |
| Just clip to a shape | `ClipPath(clipper: CustomClipper)` — not a painter |
| Tap/drag a painted region | wrap `CustomPaint` in `GestureDetector` |
| Raw pointer stream (signature, draw) | `Listener` (`onPointerDown/Move/Up`) |
| Resolve drag-vs-scroll / nested detectors | gesture arena / `RawGestureDetector` |

Prefer a real widget when one exists; reach for `CustomPaint` only for genuinely custom drawing.

## Core rules
- **`shouldRepaint` compares inputs, never returns a constant.** `=> true` repaints every frame (jank); `=> false` after inputs changed paints stale pixels. Compare exactly the fields that affect drawing.
- **Allocate nothing in `paint()`.** `Paint()`, `Path()`, `TextPainter`, gradients per frame churn the GC. Build them once as fields/in the constructor; reuse.
- **Balance `save()`/`restore()`.** Every transform/clip you push must be popped, or it leaks into later draws. `saveLayer` is a costly offscreen pass — for plain opacity set the alpha on `Paint`, not a layer.
- **Size the canvas.** `CustomPaint` with no child and no `size:` collapses to zero — nothing paints. Pass `size:` or wrap in a sized box. `painter` draws behind the child, `foregroundPainter` on top.
- **A painter has no gestures.** Wrap `CustomPaint` in `GestureDetector`/`Listener`. Transparent regions don't hit-test; pick `HitTestBehavior.opaque/translucent/deferToChild` deliberately.

## Common mistakes
```dart
// avoid: repaints every single frame even when nothing changed
@override
bool shouldRepaint(covariant RingPainter old) => true;
// do: repaint only when a drawing input actually changed
@override
bool shouldRepaint(covariant RingPainter old) =>
    old.progress != progress || old.color != color;
```

```dart
// avoid: a fresh Paint allocated on every frame → GC churn, jank
@override
void paint(Canvas canvas, Size size) {
  final paint = Paint()..color = color..strokeWidth = 8;
  canvas.drawCircle(size.center(Offset.zero), 40, paint);
}
// do: cache the Paint as a field, mutate only what changes
final Paint _stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 8;
@override
void paint(Canvas canvas, Size size) {
  _stroke.color = color;
  canvas.drawCircle(size.center(Offset.zero), 40, _stroke);
}
```

```dart
// avoid: nothing paints — no child and no size, so CustomPaint is 0x0
CustomPaint(painter: RingPainter())
// do: give it a size (or a sized child)
CustomPaint(size: const Size(120, 120), painter: RingPainter())
```

## Gotchas
- **`shouldRepaint` is the single biggest footgun** — a constant `true`/`false` is almost always wrong; compare the real inputs, and remember the painter is a *new* instance each rebuild.
- **`saveLayer` ≠ free** — it allocates an offscreen buffer and forces a composite; only use it for real group opacity/blend, never for a single shape's alpha. See `flutter-optimization` for Impeller raster cost.
- **Repaint isolation** — wrap an animated/continuously-repainting `CustomPaint` in `RepaintBoundary` so it doesn't dirty the rest of the layer; don't sprinkle boundaries everywhere.
- **Gesture arena** — a `GestureDetector` with `onPanUpdate` inside a scrollable steals the scroll; nested detectors fight in the arena. Resolve with the right recognizer or `RawGestureDetector`.
- **Hit testing painted pixels** — `Path.contains(offset)` (or a `hitTest` override on the painter) tells you if a tap landed on the drawn shape, not just its bounding box.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (analyzer clean, shouldRepaint compares inputs, no per-frame Paint allocation, gestures land, save/restore balanced).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- `CustomPainter` contract, `paint` + `shouldRepaint`, Paint caching, sizing, `RepaintBoundary`, and a complete `Listenable`-driven progress-ring example: read `reference/custom-painter.md`.
- Canvas draw ops, `Path` building + metrics, transforms, clip, save/restore/saveLayer, `TextPainter`, gradients/shaders: read `reference/canvas-paths.md`.
- `GestureDetector`, `HitTestBehavior`, `Listener`/raw pointers, gesture arena, and hit testing painted regions: read `reference/gestures-hit-testing.md`.

**Check:** `dart analyze` clean; `shouldRepaint` compares the fields that affect drawing; no `Paint()`/`Path()`/`TextPainter` allocated inside `paint()`; gestures land on the painted region; every `save()`/`clip` has a matching `restore()`.
