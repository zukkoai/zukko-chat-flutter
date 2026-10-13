# Memory, GC, and leak prevention

## How Dart's garbage collector works

Dart uses a **generational, mark-and-sweep** collector:
- **Young generation:** short-lived objects (most widgets, build-time temporaries) are allocated in a small scavenge space and collected cheaply and often. This is why throwaway allocations are tolerable — but reducing them in `build()` still cuts GC pressure and pauses.
- **Old generation:** objects that survive enough scavenges are promoted and collected by a slower mark-and-sweep pass.
- **The key rule:** the GC **cannot collect any object that is still reachable** from a live reference. A leak in Dart is not "memory the GC missed" — it is an object you forgot to stop referencing.

So leaks come from lingering references: an un-cancelled `StreamSubscription`, a listener never removed, a `Timer` still firing, a controller never disposed, or a `BuildContext`/widget captured in a long-lived object. Each keeps its entire object graph alive.

## Dispose everything you create; cancel everything you subscribe to

```dart
class _MyState extends State<MyWidget> {
  final _controller = TextEditingController();
  late final AnimationController _anim;
  StreamSubscription<Data>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _sub = stream.listen(_onData);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    someNotifier.addListener(_onNotify);
  }

  @override
  void dispose() {
    _controller.dispose();        // TextEditing/Scroll/PageController/etc.
    _anim.dispose();              // AnimationController
    _sub?.cancel();               // StreamSubscription
    _timer?.cancel();             // Timer
    someNotifier.removeListener(_onNotify); // listeners you added
    super.dispose();
  }

  Future<void> _load() async {
    final data = await repo.fetch();
    if (!mounted) return;         // guard setState after async (see analyze skill)
    setState(() => _items = data);
  }
}
```

If you own a `StreamController`, also `close()` it in `dispose()`.

## Leak checklist

- [ ] `TextEditingController`/`ScrollController`/`PageController`/`TabController` → `dispose()`.
- [ ] `AnimationController` → `dispose()`.
- [ ] `StreamSubscription` → `cancel()`; `StreamController`/sinks → `close()`.
- [ ] `Timer`/`Timer.periodic` → `cancel()`.
- [ ] Every `addListener` paired with `removeListener` (notifiers, animations).
- [ ] `mounted` checked after **every** `await` before `setState`/`context`.
- [ ] `BuildContext` never stored in a field, singleton, or closure that outlives the widget.
- [ ] Allocations minimized in `build()` (move constants/formatters to fields or statics).

The **analyze** skill's `cancel_subscriptions`/`close_sinks`/`use_build_context_synchronously` lints catch many of these automatically — enable them as errors.
