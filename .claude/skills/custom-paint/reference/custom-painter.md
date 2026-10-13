# CustomPainter contract, repaint, and sizing

- [The contract](#the-contract)
- [shouldRepaint: the load-bearing method](#shouldrepaint-the-load-bearing-method)
- [Never allocate in paint()](#never-allocate-in-paint)
- [Sizing CustomPaint](#sizing-custompaint)
- [painter vs foregroundPainter](#painter-vs-foregroundpainter)
- [Repaint isolation with RepaintBoundary](#repaint-isolation-with-repaintboundary)
- [Worked example: animated progress ring driven by a Listenable](#worked-example-animated-progress-ring-driven-by-a-listenable)

## The contract

`CustomPainter` has two methods you must implement and a few you can override:

```dart
class RingPainter extends CustomPainter {
  RingPainter({required this.progress, required this.color});
  final double progress;        // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) { /* draw here */ }

  @override
  bool shouldRepaint(covariant RingPainter old) =>
      old.progress != progress || old.color != color;

  // optional: override only if your painter exposes semantics (a11y labels)
  @override
  bool shouldRebuildSemantics(covariant RingPainter old) => false;
}
```

- `paint(canvas, size)` — `size` is the box the `CustomPaint` was laid out to. Draw relative to it; never assume a fixed pixel size.
- `shouldRepaint(old)` — Flutter passes the **previous** painter instance. A new painter is created on every parent rebuild, so this is where you decide whether to actually re-run `paint`.

## shouldRepaint: the load-bearing method

This is the single biggest footgun. A constant is almost always wrong:

```dart
// avoid: => true  → repaints every frame the parent rebuilds, even when nothing drawn changed (jank)
// avoid: => false → never repaints after inputs change → stale pixels on screen
@override
bool shouldRepaint(covariant RingPainter old) => true;

// do: compare exactly the fields that change what gets drawn
@override
bool shouldRepaint(covariant RingPainter old) =>
    old.progress != progress || old.color != color;
```

- Compare **only** drawing inputs. Don't compare callbacks or fields that don't affect pixels.
- If the painter is driven by a `Listenable` via `repaint:` (see the example below), the `Listenable` triggers repaints directly and `shouldRepaint` only handles config changes.

## Never allocate in paint()

`paint()` can run 60–120 times per second. Allocating `Paint`, `Path`, `TextPainter`, or gradient objects inside it churns the GC and drops frames. Build them once; mutate only what changes per frame.

```dart
// avoid: a new Paint and Path every frame
@override
void paint(Canvas canvas, Size size) {
  final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8;
  final path = Path()..addOval(Offset.zero & size);
  canvas.drawPath(path, p);
}

// do: cache as fields; mutate the cheap bits per frame
final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 8
  ..strokeCap = StrokeCap.round;

@override
void paint(Canvas canvas, Size size) {
  _stroke.color = color;             // cheap mutation, no allocation
  canvas.drawArc(Offset.zero & size, -math.pi / 2, 2 * math.pi * progress, false, _stroke);
}
```

Color values use `withValues`, not the removed `withOpacity`:

```dart
_stroke.color = color.withValues(alpha: 0.4);
```

## Sizing CustomPaint

`CustomPaint` sizes itself from its `child`. With **no child and no `size:`** it collapses to zero and nothing paints — the most common "my painter doesn't show up" bug.

```dart
// avoid: 0x0 — invisible
CustomPaint(painter: RingPainter(progress: 0.6, color: Colors.teal))

// do: give an explicit size...
CustomPaint(size: const Size(120, 120), painter: RingPainter(progress: 0.6, color: Colors.teal))

// ...or let a sized child define the bounds
SizedBox.square(
  dimension: 120,
  child: CustomPaint(painter: RingPainter(progress: 0.6, color: Colors.teal)),
)
```

`size:` is only honored when there is no child; with a child the child's layout wins.

## painter vs foregroundPainter

```dart
CustomPaint(
  painter: GridPainter(),            // drawn BEHIND the child
  foregroundPainter: BadgePainter(), // drawn ON TOP of the child
  child: const Text('42'),
)
```

Use `foregroundPainter` to overlay (selection ring, highlight, watermark) without obscuring the child; use `painter` for backgrounds.

## Repaint isolation with RepaintBoundary

A continuously-repainting painter (anything animated) dirties its layer every frame. Wrap it so it doesn't force the rest of the tree to re-rasterize:

```dart
RepaintBoundary(
  child: CustomPaint(size: const Size(120, 120), painter: RingPainter(...)),
)
```

Apply where a small region repaints far more often than its surroundings — not everywhere. Each boundary is its own layer and costs memory. For Impeller raster cost and when boundaries help vs hurt, see `flutter-optimization`.

## Worked example: animated progress ring driven by a Listenable

The clean pattern: pass an `Animation`/`Listenable` to the painter via `super(repaint: ...)`. The painter repaints whenever the listenable ticks — no `AnimatedBuilder`, no `setState`, no rebuild of the painter on every frame.

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProgressRing extends StatefulWidget {
  const ProgressRing({super.key, required this.value}); // 0..1
  final double value;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late Animation<double> _anim = AlwaysStoppedAnimation(widget.value);

  @override
  void didUpdateWidget(covariant ProgressRing old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween(begin: _anim.value, end: widget.value)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose(); // mandatory — leaks the ticker otherwise
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size.square(120),
        painter: _RingPainter(_anim, Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color) : super(repaint: progress);
  final Animation<double> progress; // a Listenable → drives repaint directly
  final Color color;

  // cached once; never allocated in paint()
  final Paint _track = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(_arc.strokeWidth / 2);
    _track.color = color.withValues(alpha: 0.15);
    _arc.color = color;
    canvas.drawArc(inset, 0, 2 * math.pi, false, _track);
    canvas.drawArc(inset, -math.pi / 2, 2 * math.pi * progress.value, false, _arc);
  }

  // repaint: progress handles ticks; this only catches color/config changes
  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.progress != progress;
}
```

- `super(repaint: progress)` — the painter listens to the animation itself; the framework repaints on each tick without rebuilding the painter.
- `Paint`s are fields, mutated per frame, never reallocated.
- `shouldRepaint` compares config (`color`, the animation identity), not a constant.
- `RepaintBoundary` keeps the ring's per-frame repaints off the rest of the layer.
