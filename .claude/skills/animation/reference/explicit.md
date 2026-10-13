# Explicit animation

`AnimationController` needs a `vsync` (a `TickerProvider`) and **must be disposed**. Use `SingleTickerProviderStateMixin` (one controller) or `TickerProviderStateMixin` (several).

```dart
class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = Tween(begin: 1.0, end: 1.2)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _c.reverse();
      if (s == AnimationStatus.dismissed) _c.forward();
    });
    _c.forward(); // or _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose(); // mandatory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      // child built ONCE, not on every tick — key perf win
      child: const Icon(Icons.favorite, color: Colors.red, size: 48),
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
    );
  }
}
```

`repeat()` / `forward()` / `reverse()` / `stop()` control playback.

## Performance

- Pass the static subtree to `AnimatedBuilder`'s `child` param so it isn't rebuilt every frame.
- Wrap animated subtrees in `RepaintBoundary` to isolate repaints.
- Animate cheap properties (opacity, transform) over expensive ones (layout, shadows, `clipBehavior`).
- Keep `builder` callbacks tiny; do work in `initState`, not per tick.

## Do / avoid

- Do dispose every `AnimationController`.
- Avoid rebuilding the whole tree each frame — use the `child` param.
- Avoid long-running explicit animations when an implicit widget suffices.
