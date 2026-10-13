# Implicit animations

Just change a value and rebuild — Flutter tweens for you.

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  width: _expanded ? 240 : 120,
  color: _expanded ? Colors.indigo : Colors.teal,
)

AnimatedOpacity(
  opacity: _visible ? 1 : 0,
  duration: const Duration(milliseconds: 200),
  child: const Text('Fade me'),
)

AnimatedSwitcher(
  duration: const Duration(milliseconds: 250),
  transitionBuilder: (child, anim) =>
      FadeTransition(opacity: anim, child: child),
  child: Text('$count', key: ValueKey(count)), // key required to detect change
)

TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: _rating),
  duration: const Duration(milliseconds: 400),
  builder: (_, value, __) => StarBar(value: value),
)
```

## Notes
- `AnimatedSwitcher` children **must** have unique `Key`s, or Flutter won't detect a swap.
- `TweenAnimationBuilder` animates whenever its `tween.end` changes — good for one-shot, value-driven motion without a controller.
- Implicit widgets handle their own lifecycle — nothing to dispose.
