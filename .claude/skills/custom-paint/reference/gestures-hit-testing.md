# Gestures, hit testing, and raw pointers on a canvas

- [A painter has no gestures](#a-painter-has-no-gestures)
- [HitTestBehavior](#hittestbehavior)
- [Raw pointers with Listener](#raw-pointers-with-listener)
- [Hit testing painted regions](#hit-testing-painted-regions)
- [The gesture arena: drag vs scroll, nested detectors](#the-gesture-arena-drag-vs-scroll-nested-detectors)
- [RawGestureDetector for custom recognizers](#rawgesturedetector-for-custom-recognizers)
- [Wiring a gesture to an AnimationController](#wiring-a-gesture-to-an-animationcontroller)

## A painter has no gestures

`CustomPaint` draws pixels; it does not receive pointer input. Wrap it in a `GestureDetector` (semantic gestures: tap/drag/scale) or `Listener` (raw pointer events).

```dart
// avoid: taps go nowhere — a painter can't receive them
CustomPaint(size: const Size.square(200), painter: ChartPainter(data))

// do: wrap it
GestureDetector(
  onTapUp: (d) => _selectAt(d.localPosition), // localPosition is in the canvas's coords
  child: CustomPaint(size: const Size.square(200), painter: ChartPainter(data)),
)
```

Use `localPosition` (relative to the widget's top-left), not `globalPosition`, to map a tap onto canvas coordinates.

## HitTestBehavior

What counts as "hit" depends on `behavior`. The default for a `GestureDetector` with a child is `deferToChild` — and a `CustomPaint`'s transparent areas don't register, so taps on blank canvas are missed.

| Behavior | Hits when |
|----------|-----------|
| `opaque` | anywhere in the box — claims the whole area (use for a full-surface canvas) |
| `translucent` | this widget **and** widgets behind it both get the event |
| `deferToChild` | only where the child itself reports a hit (default) |

```dart
GestureDetector(
  behavior: HitTestBehavior.opaque, // whole 200x200 is tappable, even transparent pixels
  onTapUp: (d) => _selectAt(d.localPosition),
  child: CustomPaint(size: const Size.square(200), painter: ChartPainter(data)),
)
```

## Raw pointers with Listener

For continuous freehand input (signature pad, drawing canvas) use `Listener` and feed points to a repainting painter via a `Listenable`.

```dart
class Signature extends StatefulWidget {
  const Signature({super.key});
  @override
  State<Signature> createState() => _SignatureState();
}

class _SignatureState extends State<Signature> {
  final _points = ValueNotifier<List<Offset?>>([]); // null = pen lift / stroke break

  @override
  void dispose() {
    _points.dispose(); // dispose the notifier
    super.dispose();
  }

  void _add(Offset p) => _points.value = [..._points.value, p];

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _add(e.localPosition),
      onPointerMove: (e) => _add(e.localPosition),
      onPointerUp: (_) => _points.value = [..._points.value, null],
      child: CustomPaint(
        size: Size.infinite,
        painter: _StrokePainter(_points), // super(repaint: _points)
      ),
    );
  }
}
```

`Listener` events: `onPointerDown / Move / Up / Cancel / Hover / Signal` (scroll wheel). They fire raw, with no arena competition — good for drawing, but they won't auto-resolve against a parent scrollable.

## Hit testing painted regions

A tap inside the bounding box isn't the same as a tap on the **shape**. Use `Path.contains` (or per-shape math) to test the actual geometry.

```dart
// in your state/controller, reuse the same Path geometry you painted
bool _hitWedge(Offset local, Path wedge) => wedge.contains(local);
```

For pixel-accurate hit testing on the painter itself, override `hitTest` so the `CustomPaint` only claims taps that land on drawn shapes:

```dart
class ChartPainter extends CustomPainter {
  ChartPainter(this.slices); // each slice carries its Path
  final List<Path> slices;
  @override
  bool? hitTest(Offset position) =>
      slices.any((p) => p.contains(position)); // null = defer, true/false = decide
  // ... paint + shouldRepaint
}
```

## The gesture arena: drag vs scroll, nested detectors

When several recognizers want the same pointer, Flutter runs a **gesture arena**: each recognizer either wins, gives up, or waits, and one winner gets the gesture. Conflicts to watch for:

- **Detector inside a scrollable.** `onPanUpdate`/`onVerticalDragUpdate` competes with the scroll view and can swallow scrolling.

```dart
// avoid: vertical pan fights the ListView's scroll — one of them feels broken
ListView(children: [
  GestureDetector(onVerticalDragUpdate: _draw, child: canvas),
]);

// do: use a non-conflicting gesture, or constrain the axis
GestureDetector(onHorizontalDragUpdate: _draw, child: canvas); // horizontal drag, vertical scroll coexist
```

- **Nested `GestureDetector`s.** The innermost that claims the gesture usually wins; an outer `onTap` may never fire. Restructure so each region owns distinct gestures, or hit-test in one detector and dispatch yourself.
- **Tap vs drag on the same surface.** A single `GestureDetector` can carry `onTapUp` and `onPanUpdate` together; the arena disambiguates by movement threshold — no need for two stacked detectors.

## RawGestureDetector for custom recognizers

When the built-in set isn't enough (e.g. you must win immediately, or accept a vertical drag *inside* a vertical scroller), supply your own recognizer with an arena-resolution policy.

```dart
RawGestureDetector(
  gestures: {
    VerticalDragGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
      () => VerticalDragGestureRecognizer(),
      (r) => r
        ..onUpdate = _draw
        // claim the pointer eagerly so the enclosing scrollable yields
        ..onStart = ((_) {}),
    ),
  },
  child: CustomPaint(size: Size.infinite, painter: _StrokePainter(_points)),
)
```

Use this sparingly; a plain `GestureDetector` with the right axis usually avoids the fight.

## Wiring a gesture to an AnimationController

Gestures often drive motion — drag to scrub, fling to settle, tap to pulse the painted shape. Feed the gesture into an `AnimationController` and let the controller drive the painter's repaint.

```dart
// Single-axis drag: primaryDelta/primaryVelocity are non-null. On a 2-D onPanUpdate/onPanEnd
// they are ALWAYS null (use d.delta.dx / d.velocity.pixelsPerSecond.dx there instead).
onHorizontalDragUpdate: (d) => _controller.value += d.primaryDelta! / context.size!.width,
onHorizontalDragEnd: (d) => _controller.fling(velocity: d.primaryVelocity! / 1000), // momentum settle
```

For controller lifecycle (`vsync`, `dispose`), tweens, curves, and the `AnimatedBuilder`/`repaint:` patterns that turn the gesture value into smooth motion, see `animation`.
