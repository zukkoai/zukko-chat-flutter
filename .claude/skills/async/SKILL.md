---
name: async
description: Writes correct asynchronous Dart with Futures, Streams, isolates, async/await, unawaited, and cancellation. Use for concurrency, background work, or debugging stream and Future bugs like races, leaks, or unhandled errors.
---

You are a Dart async expert who writes non-blocking, leak-free concurrent code.

## When to use
- Writing or reviewing code with `await`, `async`/`async*`, streams, or timers.
- Adding concurrency, background work, or fixing UI jank/leaks.

## Future vs Stream

| Use | When |
| --- | --- |
| `Future<T>` | A single value produced once (HTTP call, file read, DB query) |
| `Stream<T>` | Zero or more values over time (websocket, user events, file lines) |

## Key rules
- **Await and handle errors**: every async path has `try/catch`; signal failure via `throw`/`Future.error`, never a sentinel.
- **Parallelize independent work** with `Future.wait` (or record `.wait`) — don't chain sequential awaits.
- **Mark fire-and-forget** with `unawaited(...)`; never silently drop a future (unhandled async errors crash the zone).
- **Cancel subscriptions, close controllers** in `dispose`/`tearDown`, or they leak and keep callbacks alive.
- **Offload CPU work** with `Isolate.run` (Flutter: `compute`); the event loop is single-threaded.
- **Never block the loop** with heavy synchronous computation on the main isolate.
- Use `Isolate.run` for CPU work only — not I/O; use async for I/O.

```dart
// Sequential = a + b + c. Parallel = max(a, b, c).
final (a, b, c) = await (fetchA(), fetchB(), fetchC()).wait;
```

## Common mistakes
- Fire-and-forget future → `await` it (try/catch) or mark `unawaited(...)` deliberately; handle `Future.error`.
- `Timer`/`StreamSubscription` never cancelled → cancel in `dispose`/`onClose`; close controllers.
- Empty `catch {}` / silent `catchError` → log and rethrow, or convert to a typed failure.
- Stale state after `await`: the suspension point lets things change — re-check conditions/`mounted` after the gap.

## Gotchas
- **Cancel every `StreamSubscription`** in `dispose`/`onClose`/`tearDown` (and close controllers) — a live subscription pins its callback's whole object graph and leaks.
- **Use `unawaited()` deliberately** — only to mark a genuinely fire-and-forget future; an accidentally dropped future swallows errors and can crash the zone.
- **Prefer `Isolate.run` over `Isolate.spawn`** for one-off CPU work (Flutter: `compute`) — `spawn` is low-level boilerplate; `Isolate.run` is the modern API.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (compiles, analyzer clean, tests pass).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Futures: await/error handling, `Future.wait` semantics, `unawaited`, debounce/throttle — read `reference/futures.md`.
- Streams: single vs broadcast, `async*`/`yield`, `await for`, cancellation & leak prevention — read `reference/streams.md`.
- Isolates: `Isolate.run`/`compute`, what's sendable, when to use them — read `reference/isolates.md`.
- Anti-patterns with do/avoid examples (unawaited futures, leaked timers/subscriptions, swallowed errors, async gaps): read `reference/anti-patterns.md`.
