# GC & memory

## How Dart's GC works

Dart uses a **generational, mark-and-sweep** garbage collector:

- **Young (new) generation**: a small space where most objects are born. Short-lived objects (the common case) are collected here with a fast scavenge — cheap.
- **Old generation**: objects that survive several young-gen collections are promoted here, swept less often with a parallel mark-and-sweep.
- You **cannot free memory manually** — no `free`/`delete`. The collector reclaims any object that is no longer reachable.

Consequence: you optimize memory by **reducing allocations** and **dropping references**, not by freeing.

## Reduce allocations

- **Prefer `const`** — const values are canonicalized: built once at compile time, shared everywhere, zero runtime allocation.
- **Hoist invariants out of loops and `build`** — don't construct the same regex, buffer, or object every iteration/frame.
- **Reuse objects** instead of recreating identical ones.
- **`StringBuffer`** instead of repeated `+` (each `+` allocates a new `String`).
- **Lazy `Iterable`** — avoid intermediate `.toList()` calls; materialize once.

```dart
// Avoid: allocates a new EdgeInsets and list every build
Widget build(BuildContext context) {
  final padding = EdgeInsets.all(16);
  final colors = [Colors.red, Colors.blue];
  // ...
}

// Prefer: const = zero allocation, shared instance
Widget build(BuildContext context) {
  const padding = EdgeInsets.all(16);
  const colors = [Colors.red, Colors.blue];
  // ...
}
```

## Leaks the GC can't collect

The GC only reclaims **unreachable** objects. These stay reachable (via the framework, a timer queue, or global state) until you release them:

| Source | Fix |
| --- | --- |
| `StreamSubscription` from `.listen(...)` | `await sub.cancel()` in `dispose`/`tearDown` |
| `StreamController` / sinks | `await controller.close()` |
| `Timer` / `Timer.periodic` | `timer.cancel()` |
| `addListener` / `ChangeNotifier` / `AnimationController` | `removeListener(...)` / `dispose()` |
| Retained global or `static` state holding large objects | null it out or scope it tighter |

```dart
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription<int>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sub = stream.listen(_onData);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    _sub?.cancel();   // else the closure + State stay alive forever
    _timer?.cancel();
    super.dispose();
  }
}
```

The lints `cancel_subscriptions` and `close_sinks` catch the common misses.

## Profiling

Use **DevTools → Memory**:

- Watch the heap chart and **GC events**; a sawtooth that never returns to baseline signals a leak.
- Take heap snapshots before/after an action; compare retained sizes.
- Use the allocation profiler to find hot allocation sites in loops and `build`.
