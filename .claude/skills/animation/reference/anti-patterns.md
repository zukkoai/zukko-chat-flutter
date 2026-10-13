# Animation anti-patterns: do / avoid

Explicit animations leak and jank in two predictable ways: the controller isn't
disposed (or is recreated in `build`), and the whole animated subtree rebuilds on
every tick. (Flutter 3.44 / Dart 3.12.)

## 5. `AnimationController` created in `build` / not disposed
An `AnimationController` is a `Ticker`-backed, long-lived object. Creating it in
`build` spins up a new ticker on every rebuild (multiple tickers fighting,
leaks); not disposing it leaks the ticker and its callbacks. Create it once in
`initState` with a `vsync`, and `dispose()` it.

```dart
// Avoid: new controller every rebuild, never disposed → leaked tickers.
class Pulse extends StatelessWidget {
  const Pulse({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AnimationController(             // recreated each build
      vsync: ... , duration: const Duration(seconds: 1),
    )..repeat();                              // never disposed → leak
    return FadeTransition(opacity: c, child: const Icon(Icons.favorite));
  }
}

// Do: create once with vsync in initState, dispose in dispose.
class Pulse extends StatefulWidget {
  const Pulse({super.key});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();           // releases the ticker + listeners
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: const Icon(Icons.favorite));
}
```

Use `SingleTickerProviderStateMixin` for one controller,
`TickerProviderStateMixin` for several.

## Rebuild scope: use `AnimatedBuilder`'s `child`
The `builder` of `AnimatedBuilder` (and `AnimatedWidget`/`TweenAnimationBuilder`)
runs every frame. Anything constructed inside it is rebuilt 60–120x/second. Build
the static subtree **once**, pass it as the `child` argument, and only wrap the
animated property in the builder.

```dart
// Avoid: the (expensive, unchanging) content is rebuilt every frame.
AnimatedBuilder(
  animation: _c,
  builder: (context, _) => Transform.rotate(
    angle: _c.value * 2 * pi,
    child: const ExpensiveBadge(),   // rebuilt 60+ times/sec for nothing
  ),
);

// Do: build the child once; the builder only applies the transform.
AnimatedBuilder(
  animation: _c,
  child: const ExpensiveBadge(),     // built once, reused each frame
  builder: (context, child) => Transform.rotate(
    angle: _c.value * 2 * pi,
    child: child,
  ),
);
```

For continuously animating subtrees, also wrap them in a `RepaintBoundary` so the
repaint stays on its own layer and doesn't dirty siblings.
