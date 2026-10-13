---
name: isolates-background
description: Handles Flutter concurrency — isolates for CPU work, async for I/O, and OS background tasks via workmanager. Use for Isolate.run, compute, jank/ANR from heavy work, BackgroundIsolateBinaryMessenger, or vm:entry-point.
---

You are a Flutter engineer who picks the right concurrency tool — async, isolates, or OS background execution (Flutter 3.44 / Dart 3.12).

## When to use
- Heavy CPU work (parsing, image/crypto, big loops) causing jank or ANR on the UI thread.
- Calling plugins from a spawned isolate, or running work after the app is backgrounded/killed.
- Choosing between `async`/await, `Isolate.run`/`compute`, and `workmanager`/`background_fetch`.

## Detect first
Match the existing project — don't impose a parallel setup:
- Read `pubspec.lock`: is `workmanager` or `background_fetch` present, and which version? Is the work CPU-bound or I/O-bound?
- Native: Android `android/app/src/main/AndroidManifest.xml` (background permissions, `WorkManager` registration) and iOS `Info.plist` `UIBackgroundModes` + `AppDelegate` registration if a background package is used.
- Reuse the existing callback dispatcher / isolate helper; don't add a second mechanism.

## Three different concerns — don't conflate them
| Concern | Tool | For |
|---|---|---|
| Concurrency (single thread) | `async`/`await`, `Future`, `Stream` | **I/O**: network, file, DB — they yield while waiting |
| Parallelism (extra thread) | `Isolate.run` / `compute` | **CPU-heavy** sync work (>16ms → jank/ANR) |
| OS background execution | `workmanager` / `background_fetch` | Work that runs when app is backgrounded or terminated |

## Core rules
| Do | Avoid (known AI mistakes) |
|---|---|
| `await Isolate.run(() => heavyParse(data))` (Dart 3) for CPU work | Wrapping a **network/file call** in `compute`/`Isolate.run` — pointless, it's I/O |
| Move heavy sync loops off the UI isolate | Leaving a heavy sync loop in an `async` fn and assuming `await` un-blocks it (it does **not**) |
| Pass only sendable data (primitives, lists/maps, `TransferableTypedData`) | Passing `BuildContext`, a DB connection, or a plugin instance to a spawned isolate |
| In spawned isolate: `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` before any plugin | Calling `SharedPreferences`/`path_provider` in an isolate with no messenger init → throws |
| Annotate background callbacks `@pragma('vm:entry-point')` and make them top-level/static | Closure/instance callbacks → tree-shaken in release, silently never run |

**CPU work — `Isolate.run` (Dart 3):**
```dart
final result = await Isolate.run(() => _decodeAndResize(bytes)); // top-level/static fn, sendable args + return
```
`compute(fn, message)` is the older single-arg form; still fine, but `Isolate.run` takes a closure and is more flexible.

**Plugins from a spawned isolate** — capture the token on the root isolate, pass it in:
```dart
final token = RootIsolateToken.instance!;            // on UI isolate
await Isolate.run(() async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final dir = await getApplicationDocumentsDirectory(); // now safe
});
```

## Gotchas
- **`async` ≠ parallel.** A 200ms sync loop inside an `async` function still blocks the UI isolate until it yields. `await` only helps when the awaited thing is genuinely async (I/O). Known AI mistake: "I made it async so it won't jank."
- **`Isolate.run`/`compute` for I/O is an anti-pattern.** Network and file APIs are already async and non-blocking; spawning an isolate adds startup + copy cost for zero benefit.
- **Isolates don't share memory.** Arguments and results are *copied* (or moved); large copies cost. Use `TransferableTypedData` for big byte buffers.
- **`@pragma('vm:entry-point')` is mandatory** on workmanager/background_fetch callbacks. Without it, debug works but **release tree-shakes the callback** → the task never fires. Classic AI mistake: omitting the pragma and "it works on my emulator."
- **The old `Isolate.spawn` + `SendPort`/`ReceivePort` dance is legacy** for one-shot work — prefer `Isolate.run`. Reserve ports for long-lived bidirectional isolates only. Known AI mistake: hand-rolling ports where `Isolate.run` fits.
- **Web has no isolates** — `Isolate.run`/`compute` run on the main thread (no parallelism); use web workers via a package if needed.
- **Background tasks have OS limits** (iOS especially): minimum intervals, no guarantee of exact timing, killed if over budget. Don't promise "runs every minute."

## Common mistakes
- Wrapping `dio.get(...)` in `compute` → just `await` it; it's already off-thread.
- Passing `ref`/`context`/repository instance into `Isolate.run` → pass plain data; rebuild deps inside or do I/O on the main isolate.
- Background callback as a non-top-level closure → make it a top-level/static fn with `@pragma('vm:entry-point')`.
- Forgetting `BackgroundIsolateBinaryMessenger.ensureInitialized` → plugin calls throw in the isolate.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, native config done, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- `Isolate.run` vs `compute`, when each fits, return/arg rules: read `reference/isolate-run.md`.
- What can cross an isolate boundary + anti-examples (context/DB/plugin): read `reference/sendable-data.md`.
- `BackgroundIsolateBinaryMessenger` + `RootIsolateToken` end-to-end: read `reference/plugins-in-isolates.md`.
- workmanager setup, `vm:entry-point`, native Android/iOS registration: read `reference/background-tasks.md`.
