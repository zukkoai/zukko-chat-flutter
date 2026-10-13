---
name: platform-channels
description: Builds native interop in Flutter — Pigeon type-safe channels, MethodChannel/EventChannel, and dart:ffi for C/C++. Use for invokeMethod, EventChannel streams, ffigen bindings, codec type errors, or platform-thread ANRs.
---

You are a Flutter engineer who builds native interop correctly with Pigeon, platform channels, and FFI (Flutter 3.44 / Dart 3.12).

## When to use
- Calling native Android/iOS code from Dart, or pushing native events back to Dart.
- Binding a C/C++ library via `dart:ffi` + `ffigen`.
- Authoring a plugin, or debugging codec type errors / platform-thread ANRs.

## Detect first
Match the existing project — don't impose a parallel setup:
- Read `pubspec.lock`: is `pigeon` (dev) or `ffigen` (dev) present, and which version? Any existing `MethodChannel('...')` names?
- Native: Android `android/.../MainActivity.kt` or plugin `*Plugin.kt` for `setMethodCallHandler`; iOS `ios/Runner/AppDelegate.swift` or `*Plugin.swift` for `FlutterMethodChannel`.
- Generated files: `pigeons/*.dart` + generated host/Dart APIs; `ffigen.yaml` + generated bindings.
- Reuse the existing channel/codec; don't add a parallel stringly-typed channel beside a Pigeon one.

## Core rules
| Do | Avoid (known AI mistakes) |
|---|---|
| Use **Pigeon** for any non-trivial API (type-safe generated host + Dart) | Hand-rolling `MethodChannel.invokeMethod('name', map)` for multi-method APIs — the default AI mistake |
| Match codec types exactly across the boundary | Assuming Dart `int` is Java `int` — it maps to `Long`/`NSNumber`; mismatch throws at runtime |
| Use **EventChannel** for native→Dart streams | Polling with repeated `invokeMethod` calls |
| Do heavy native work on a **background thread** (Android `@TaskQueue` / dispatch queue) | Blocking the platform/main thread → ANR / dropped frames |
| Manage FFI memory: `malloc`/`calloc` then `free` (or `using`) | Leaking native memory; wrong `Int32`/`Pointer` typedefs → corruption |

## Pick the mechanism
| Need | Use |
|---|---|
| Structured request/response API to native | **Pigeon** |
| One-off / simple call, no codegen | raw `MethodChannel` |
| Continuous native→Dart stream (sensors, location) | **EventChannel** |
| Call a C/C++ library, no platform code | **dart:ffi** + `ffigen` |

## Codec type mapping (the footgun)
| Dart | Android (Kotlin/Java) | iOS (Swift) |
|---|---|---|
| `int` | `Long` / `Integer` | `NSNumber` (Int) |
| `double` | `Double` | `NSNumber` (Double) |
| `bool` | `Boolean` | `NSNumber` (Bool) |
| `String` | `String` | `String` |
| `List` | `List` | `[Any?]` |
| `Map` | `HashMap` | `[AnyHashable: Any?]` |
| `Uint8List` | `ByteArray` | `FlutterStandardTypedData` |

A returned value whose type doesn't match what Dart expects throws on cast. Pigeon **generates** these mappings so you can't get them wrong — another reason to prefer it.

## Gotchas
- **Hand-rolled `MethodChannel` is the default AI mistake** for anything non-trivial. It's stringly-typed (`'getUser'`, `map['name']`), has no compile-time checks, and silently breaks when the native side changes. Use Pigeon.
- **Dart `int` is not Java `int`.** It marshals as `Long`/`Integer`/`NSNumber`. Casting to the wrong native int width throws. Known AI mistake: writing Kotlin `call.argument<Int>("id")` for a value Dart sent as a large int.
- **Blocking the platform thread = ANR.** `MethodChannel` handlers run on the platform main thread. Heavy work there freezes the UI. On Android use a `BinaryMessenger.TaskQueue` (`@TaskQueue` / `taskQueue`) or dispatch to a background executor; on iOS hop to a background `DispatchQueue` and `result(...)` back on main.
- **`result(...)` must be called exactly once**, on the platform thread. Forgetting it leaves the Dart `Future` hanging forever; calling it twice crashes.
- **ffigen deprecated YAML keys:** older configs used keys/structure that current ffigen renames or removed. Generate with the current `ffigen` and check `pub.dev/packages/ffigen/changelog`; don't copy a years-old `ffigen.yaml`. Known AI mistake: stale `ffigen.yaml` schema.
- **FFI memory leaks:** every `malloc`/`calloc` needs a matching `free` (or wrap in `using((arena) {...})`). Wrong typedef (`Int32` vs `Int64`, missing `Pointer`) corrupts data silently.
- **EventChannel needs cancel handling.** Implement `onCancel` natively to stop the sensor/listener, or you leak native resources when Dart cancels the subscription.

## Common mistakes
- Multi-method API via raw `invokeMethod` → define a Pigeon `@HostApi()` and generate.
- Heavy native call freezing the app → move off the platform thread (TaskQueue / DispatchQueue).
- `result` never called / called twice → call it exactly once on the main thread.
- Copy-pasted old `ffigen.yaml` → regenerate with current ffigen schema.
- Forgetting to `free` FFI allocations → use `calloc`/`malloc` + `free`, or an `Arena`.

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
- Pigeon setup, `.dart` API definition, generated host code, calling: read `reference/pigeon.md`.
- Raw `MethodChannel`/`EventChannel` (when Pigeon isn't an option) + full codec table: read `reference/method-event-channel.md`.
- `dart:ffi` + ffigen, memory management, typedefs: read `reference/ffi.md`.
- ANR avoidance, Android `TaskQueue`, iOS background dispatch: read `reference/threading.md`.
- Federated plugin structure (cross-ref `packaging`): read `reference/pigeon.md`.
