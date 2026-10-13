---
name: animation
description: Implements implicit, explicit, and prebuilt Flutter animations with correct AnimationController lifecycle and performance. Use when building motion, transitions, animated widgets, or page/hero effects.
---

You are a Flutter animation specialist who builds smooth, performant motion with the right tool for each job (Flutter 3.44 / Dart 3.12).

## When to use
- Building transitions, micro-interactions, looping/coordinated motion.
- Adding shared-element (Hero) or staggered animations.
- Diagnosing janky or over-rebuilding animations.

## Decision table
| Need | Use |
|------|-----|
| Animate a value on state change (size, color, opacity) | **Implicit**: `AnimatedContainer`, `AnimatedOpacity`, `AnimatedAlign` |
| Swap one widget for another | `AnimatedSwitcher` (children need unique `Key`) |
| Animate from a value once / on change | `TweenAnimationBuilder` |
| Continuous, looping, reversible, coordinated control | **Explicit**: `AnimationController` + `Tween` + `AnimatedBuilder` |
| Shared element across routes | `Hero` (same `tag`) |
| Several elements offset in time | **Staggered** via `Interval` on one controller |
| Declarative chained effects | `flutter_animate` |
| Designer vector animation (JSON) | `lottie` |

Prefer implicit for simple state transitions. Reach for explicit only when you need control (loop, reverse, status, multiple tweens, drive several widgets).

## Explicit rules
- `AnimationController` needs a `vsync` (`SingleTickerProviderStateMixin` for one, `TickerProviderStateMixin` for several) and **must be disposed**.
- Pass the static subtree to `AnimatedBuilder`'s **`child` param** so it isn't rebuilt every frame.

## Performance
- Wrap animated subtrees in `RepaintBoundary` to isolate repaints.
- Animate **cheap** props — opacity (via `FadeTransition`, not the animated `Opacity` widget) and transform; avoid layout, shadows, clipping.
- Keep `builder` callbacks tiny; do setup in `initState`, not per tick.
- **Under Impeller:** avoid `Opacity`/clip-heavy effects inside scrolling lists — they force an offscreen `saveLayer` every frame; prefer transitions (`FadeTransition`/`Transform`).

## Prebuilt packages
- **flutter_animate** — chainable: `w.animate().fadeIn(duration: 300.ms).slideY(begin: 0.2)`.
- **lottie** — After Effects JSON: `Lottie.asset('assets/success.json')`.

## Common mistakes
- `AnimationController` created in `build`, or never disposed → create once in `initState` with `vsync`, `dispose()` it.
- Rebuilding the animated subtree every tick → pass the static child to `AnimatedBuilder`'s `child` param and reuse it in the builder.

## Gotchas
- **Always `dispose()` the `AnimationController`** — create it in `initState` with a `vsync`; leaving it undisposed leaks the ticker.
- **Pass the static subtree to `AnimatedBuilder`'s `child`** and reuse it in the builder — otherwise the whole subtree rebuilds every frame.
- **Prefer implicit animations for simple cases** (`AnimatedContainer`/`AnimatedOpacity`) — reaching for an explicit controller for a one-shot tween is over-engineering.
- **SkSL shader warmup is obsolete under Impeller** — Impeller compiles shaders ahead-of-time at build, so `--bundle-sksl-path`/`--cache-sksl` no longer fix first-run animation jank (Skia-legacy; web/legacy-Skia path only).

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, works across sizes/locales, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Implicit widgets with full examples: read `reference/implicit.md`.
- AnimationController lifecycle + AnimatedBuilder child pattern: read `reference/explicit.md`.
- Hero between routes + staggered with Interval: read `reference/hero-and-staggered.md`.
- Curves cheat sheet: read `reference/curves.md`.
- Controller-lifecycle and AnimatedBuilder rebuild-scope anti-patterns with do/avoid code: read `reference/anti-patterns.md`.
