# Canvas, Path, transforms, clips, text, and shaders

- [Paint: configure once, reuse](#paint-configure-once-reuse)
- [Canvas drawing operations](#canvas-drawing-operations)
- [Building Paths](#building-paths)
- [PathMetrics: dashes and "draw along a path"](#pathmetrics-dashes-and-draw-along-a-path)
- [Transforms](#transforms)
- [Clipping](#clipping)
- [save / restore / saveLayer](#save--restore--savelayer)
- [Drawing text with TextPainter](#drawing-text-with-textpainter)
- [Gradients and shaders](#gradients-and-shaders)

## Paint: configure once, reuse

`Paint` carries style, color, stroke, blend, and shader. Build it once (as a painter field) and mutate cheaply; never `Paint()` inside `paint()`.

```dart
final Paint _fill = Paint()..style = PaintingStyle.fill;
final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 4
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;
```

For opacity, set the alpha on the color — do **not** reach for `saveLayer`:

```dart
_fill.color = Colors.indigo.withValues(alpha: 0.3); // withValues, not withOpacity
```

## Canvas drawing operations

```dart
canvas.drawLine(a, b, _stroke);
canvas.drawRect(rect, _fill);
canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), _fill);
canvas.drawCircle(center, radius, _fill);
canvas.drawOval(rect, _stroke);
canvas.drawArc(rect, startRadians, sweepRadians, useCenter, _stroke); // pie vs ring via useCenter
canvas.drawPath(path, _stroke);
canvas.drawPoints(PointMode.polygon, offsets, _stroke); // points / lines / polygon
canvas.drawShadow(path, Colors.black, 6, true);
canvas.drawImage(image, Offset.zero, _fill);            // image is a dart:ui Image
canvas.drawImageRect(image, srcRect, dstRect, _fill);
```

- Angles are in **radians**, measured clockwise from 3 o'clock. A ring starts at `-math.pi / 2` (12 o'clock).
- `Offset.zero & size` builds the full `Rect`; `rect.center`, `rect.deflate(n)`, `rect.inflate(n)` are handy.

## Building Paths

A `Path` is a reusable shape. Build it once if static; rebuild only when the geometry actually changes.

```dart
final path = Path()
  ..moveTo(0, h)
  ..lineTo(w * 0.25, h * 0.4)
  ..quadraticBezierTo(w * 0.5, 0, w * 0.75, h * 0.5) // control point, end point
  ..cubicTo(w * 0.8, h * 0.6, w * 0.9, h, w, h * 0.3) // two controls, end
  ..arcToPoint(Offset(w, h), radius: const Radius.circular(20))
  ..close();

path.addRect(rect);
path.addRRect(rrect);
path.addOval(rect);
path.addPolygon(points, true); // close = true
path.fillType = PathFillType.evenOdd; // donut/holes; default is nonZero

final combined = Path.combine(PathOperation.difference, outer, inner); // union/intersect/xor too
```

`Path.contains(offset)` returns whether a point is inside the filled shape — use it for hit testing painted regions (see `reference/gestures-hit-testing.md`).

## PathMetrics: dashes and "draw along a path"

`computeMetrics()` measures a path so you can extract sub-segments (dashed lines, animated stroke reveal, label-on-curve).

```dart
Path dashed(Path source, {double dash = 6, double gap = 4}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    double dist = 0;
    while (dist < metric.length) {
      out.addPath(metric.extractPath(dist, dist + dash), Offset.zero);
      dist += dash + gap;
    }
  }
  return out;
}

// animate a stroke "drawing itself": extract 0..length*progress
final m = path.computeMetrics().first;
final partial = m.extractPath(0, m.length * progress);

// position/rotate a marker along the path
final tangent = m.getTangentForOffset(m.length * progress)!;
canvas.drawCircle(tangent.position, 4, _fill); // tangent.angle gives the heading
```

## Transforms

Transforms move the **canvas**, not the shapes. Apply, draw, then undo (see save/restore).

```dart
canvas.translate(dx, dy);
canvas.rotate(radians);
canvas.scale(sx, sy);
canvas.transform(matrix4.storage); // arbitrary Matrix4

// rotate about a center point, not the origin
canvas.save();
canvas.translate(center.dx, center.dy);
canvas.rotate(angle);
canvas.translate(-center.dx, -center.dy);
canvas.drawRRect(rrect, _fill);
canvas.restore();
```

## Clipping

Clips restrict subsequent drawing to a region. They persist until `restore()`, so wrap them in save/restore.

```dart
canvas.save();
canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
canvas.drawImageRect(image, src, rect, _fill); // only the rounded area shows
canvas.restore();
// also: clipRect, clipPath(path)
```

Prefer painting the rounded/decorated shape directly over heavy clipping when you can; clips can force extra compositing.

## save / restore / saveLayer

Every transform and clip you push must be popped, or it **leaks into later draws**.

```dart
// avoid: rotation and clip bleed into everything drawn afterward
canvas.rotate(0.3);
canvas.clipRect(rect);
canvas.drawPath(a, _fill);
canvas.drawPath(b, _fill); // unintentionally rotated AND clipped

// do: scope it
canvas.save();
canvas.rotate(0.3);
canvas.clipRect(rect);
canvas.drawPath(a, _fill);
canvas.restore();          // back to a clean canvas
canvas.drawPath(b, _fill); // unaffected
```

`saveLayer(bounds, paint)` allocates an **offscreen buffer** and composites it back on `restore()` — expensive. Use it only for genuine group effects (apply one opacity/blend to several shapes at once):

```dart
// legitimate use: fade a whole group together
canvas.saveLayer(bounds, Paint()..color = Colors.white.withValues(alpha: 0.5));
canvas.drawPath(a, _fill);
canvas.drawPath(b, _fill);
canvas.restore();
```

For a single shape's opacity, set the alpha on its `Paint` instead — no layer. See `flutter-optimization` for the Impeller raster cost of offscreen passes.

## Drawing text with TextPainter

`TextPainter` lays out text for the canvas. Layout is not free — cache the painter and only re-`layout()` when the string/style/width changes, never every frame for static labels.

```dart
final _label = TextPainter(textDirection: TextDirection.ltr);

void drawLabel(Canvas canvas, String text, Offset at, Color color) {
  _label
    ..text = TextSpan(text: text, style: TextStyle(color: color, fontSize: 14))
    ..layout();                                   // measures; sets _label.size
  _label.paint(canvas, at - Offset(_label.width / 2, _label.height / 2)); // centered
}
```

## Gradients and shaders

A `Gradient` becomes a `Shader` via `createShader(rect)`; assign it to `Paint.shader`. Build the shader once when the rect/colors are stable.

```dart
_fill.shader = const LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
).createShader(rect);

// SweepGradient — great for ring/gauge fills
_arc.shader = SweepGradient(
  startAngle: 0,
  endAngle: 2 * math.pi,
  colors: const [Colors.cyan, Colors.purple, Colors.cyan],
).createShader(rect);

// RadialGradient for glows; ImageShader to tile/transform an image as a brush
_fill.shader = ImageShader(image, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage);
```

A shader paints in the **canvas** coordinate space, so re-create it if the paint area changes size.
