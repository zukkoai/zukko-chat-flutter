# Hero & staggered animations

## Hero animations between routes

Wrap the source and destination in `Hero` with the **same `tag`**.

```dart
// List screen
Hero(tag: 'avatar-$id', child: CircleAvatar(backgroundImage: img))
// Detail screen
Hero(tag: 'avatar-$id', child: CircleAvatar(radius: 80, backgroundImage: img))
```

Tags must be unique per item; reusing a tag for multiple visible widgets throws.

## Staggered animations

Drive one controller; give each element its own `Interval` curve so they start at different fractions of the timeline.

```dart
final _slide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
  CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
);
final _fade = CurvedAnimation(
  parent: _c, curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
);
```

Use overlapping intervals (e.g. `0.0–0.5` and `0.3–1.0`) so motions blend rather than running strictly in sequence.

## Prebuilt packages

- **`flutter_animate`** — declarative, chainable effects: `myWidget.animate().fadeIn(duration: 300.ms).slideY(begin: 0.2)`. Great for quick polish without controllers.
- **`lottie`** — render After Effects vector animations from JSON: `Lottie.asset('assets/success.json')`. Use for rich illustrative motion.
