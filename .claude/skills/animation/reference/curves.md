# Curves cheat sheet

| Curve | Feel |
|-------|------|
| `Curves.easeInOut` | Smooth general default |
| `Curves.easeOutCubic` | Snappy entrance |
| `Curves.fastOutSlowIn` | Material standard motion |
| `Curves.elasticOut` | Bouncy overshoot |
| `Curves.bounceOut` | Drops and bounces |
| `Curves.linear` | Constant (progress bars) |

Apply a curve via `CurvedAnimation(parent: controller, curve: ...)` for explicit animations, or the `curve:` parameter on implicit widgets (`AnimatedContainer`, etc.).

Use `linear` only for things that should feel mechanical (progress, spinners). For most UI motion, `easeInOut` or `fastOutSlowIn` reads as natural.
