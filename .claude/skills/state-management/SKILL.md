---
name: state-management
description: Builds Flutter state management with Riverpod or Bloc/Cubit — providers, notifiers, events, async state. Use for app state, or when data updates but the UI won't rebuild or refresh.
---

You are a Flutter state-management engineer who writes idiomatic Riverpod 3 and flutter_bloc on Flutter 3.44 / Dart 3.12.

## When to use
- Any app/feature/shared state: providers, `Notifier`/`AsyncNotifier`, Cubit/Bloc, events.
- Wiring widgets to state and structuring async data, side effects, and DI.
- Debugging "data updates but the UI doesn't" — see the CRITICAL section below.

## Detect first
Match the existing project — never run two solutions side by side.
- Read `pubspec.lock` (then `pubspec.yaml`) to see which solution is present and its exact version (the `version:` under the package). **Follow what the project uses.**
- If `flutter_riverpod`/`riverpod_annotation` → use Riverpod. If `flutter_bloc`/`bloc` → use Bloc/Cubit. Note conventions (codegen on? `ProviderScope` at root? sealed states? Equatable/freezed?).
- If neither is present and the user states no preference → **default to Riverpod** and say so explicitly.

## Check the latest version (only when needed)
Do this ONLY when adding/upgrading a package, when the user asks for the latest, or when generated code fails due to an API change — **not on every task**. Otherwise use the baselines below.

- Project's current version: read `pubspec.lock` — no network.
- Latest + breaking changes: prefer `flutter pub add <pkg>` / `flutter pub upgrade <pkg>` (tooling resolves the newest compatible); `flutter pub outdated` lists upgradables; read the **changelog** before upgrading.

| Package | Latest page | Changelog |
|---|---|---|
| flutter_riverpod | pub.dev/packages/flutter_riverpod | pub.dev/packages/flutter_riverpod/changelog |
| riverpod_annotation | pub.dev/packages/riverpod_annotation | pub.dev/packages/riverpod_annotation/changelog |
| flutter_bloc | pub.dev/packages/flutter_bloc | pub.dev/packages/flutter_bloc/changelog |
| bloc_test | pub.dev/packages/bloc_test | pub.dev/packages/bloc_test/changelog |

**Baseline (verified 2026-06-30):** flutter_riverpod/riverpod `3.3.2` but riverpod_annotation `4.0.3` (the version lines **differ** — don't "align" them); flutter_bloc `9.1.1`, bloc_test `10.0.0`; provider `6.1.5+1`; get_it `9.2.1`. Full table + protocol: `reference/versions.md`. **If offline/no web: use the baseline and state the assumed version.** Prefer `flutter pub add <pkg>` over hardcoding.

## Choose: Riverpod vs Bloc

| Pick | When |
|---|---|
| **Riverpod** | Compile-safe DI + reactive derived state, async caching; codegen `@riverpod`. Default for new apps. |
| **Bloc** | Event-driven flows, explicit transitions, event tracing/logging, debounce/concurrency control. |
| **Cubit** | Simple imperative state (toggles, forms, counters) — `emit()` directly, less boilerplate. |
| Lighter | `provider`/`get_it` for plain DI; `setState` for purely-local, ephemeral UI state. |

Don't mix two solutions. Full guidance: `reference/choosing.md`.

## CRITICAL: State updates that actually rebuild the UI
The #1 bug: **data changes but the UI doesn't.** Flutter rebuilds only when the watched state is a NEW value that is `!=` the old one. Mutating fields or collections in place leaves the reference unchanged → `==` → no rebuild (and in Bloc, **`emit` is silently dropped when `newState == state`**).

- **Assign/emit a NEW immutable instance.** Riverpod `state = state.copyWith(...)`; Bloc `emit(NewState(...))`. Never mutate `state.field`. (`state++`/`emit(state+1)` work because they reassign.)
- **Collections — build a NEW collection,** never mutate-in-place then reuse the same `List`:
  ```dart
  // AVOID — same List reference; == old → no rebuild / emit dropped
  state.items.add(x); state = state.copyWith(items: state.items);   // Riverpod
  current.todos.add(x); emit(TodoLoaded(current.todos));            // Bloc
  // DO — new collection every time
  state = state.copyWith(items: [...state.items, x]);              // Riverpod add
  emit(TodoLoaded([...current.todos, x]));                          // Bloc add
  emit(TodoLoaded(current.todos.where((t) => t.id != id).toList())); // Bloc remove
  ```
  Same for `Map`/`Set`: `{...old, k: v}`, `{...old, x}`.
- **Value equality with ALL fields.** Equatable `props` / freezed constructor must list every field — omit one and a real change compares equal and is invisible.
- **Riverpod:** `state = AsyncData(...)` / `state = await AsyncValue.guard(...)`; `ref.watch` in `build` (not `ref.read`); `ref.watch(p.select((s) => s.field))` for slice rebuilds; guard raw writes across `await` with `if (!ref.mounted) return;` (notifiers are recreated on rebuild).
- **Bloc:** `emit(NewState())`; async guard `if (isClosed) return;` (Cubit) / `if (emit.isDone) break;` (Bloc streams); side effects (nav/snackbars/dialogs) in `BlocListener`, never in `BlocBuilder`.

**Verify state→UI checklist:** (1) NEW instance assigned/emitted, not a mutated field? (2) NEW collection, not `.add`/`.remove` on the reused list? (3) `props`/freezed fields cover ALL fields? (4) UI watches in `build` (`ref.watch` / `BlocBuilder`), not `read`? (5) async guarded (`ref.mounted` / `isClosed` / `emit.isDone`)? (6) loading + error states rendered, not just data? Full do/avoid: `reference/state-updates.md`.

## Riverpod essentials
Wrap the app in `ProviderScope`; run `dart run build_runner watch -d`. Each `@riverpod` file needs `part 'file.g.dart';`. Annotate a **function** for read-only/derived values + DI, a **class** for state you mutate.

```dart
@riverpod
ApiRepository apiRepository(Ref ref) => ApiRepository(ref.watch(dioProvider)); // DI

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;            // initial state
  void increment() => state++; // reassign -> rebuild
}
```

Read with `ref.watch(counterProvider)`; mutate via `ref.read(counterProvider.notifier).increment()`. `Future build()` → `AsyncNotifier` exposing `AsyncValue<T>` — render with `.when(data/loading/error)` or an exhaustive `switch` (`AsyncValue` is `sealed`: `AsyncData`/`AsyncError`/`AsyncLoading`); read the value with `.value` (`.valueOrNull` was removed). Providers are `autoDispose`; clean up with `ref.onDispose`; a failed `build` **auto-retries** with exponential backoff. Avoid legacy `StateProvider`/`StateNotifierProvider`/`ChangeNotifierProvider` — if you must use them, import `package:flutter_riverpod/legacy.dart`. Opt-in offline persistence (experimental) via `riverpod_sqflite`. Full detail: `reference/riverpod.md`, `reference/riverpod-async.md`.

## Bloc essentials
**Cubit** is imperative (`emit()` directly); **Bloc** is event-driven (`add(event)` → `on<Event>`). Model states with Dart 3 sealed classes + Equatable for exhaustive `switch` and value equality.

```dart
sealed class TodoState extends Equatable {
  const TodoState();
  @override
  List<Object?> get props => [];
}
final class TodoLoaded extends TodoState {
  const TodoLoaded(this.todos);
  final List<Todo> todos;
  @override
  List<Object?> get props => [todos]; // EVERY field
}
```

Provide with `BlocProvider`, rebuild with `BlocBuilder` (`switch` over states), side-effects with `BlocListener`, both with `BlocConsumer`. Dispatch via `context.read<B>().add(...)`. Start with a Cubit; promote to a Bloc when you need an event log or transformers. Full detail: `reference/bloc.md`.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, UI rebuilds on state change, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Riverpod 3 codegen setup, provider types, ConsumerWidget, lifecycle: `reference/riverpod.md`.
- AsyncNotifier load + mutate-list, `AsyncValue.guard`, `copyWithPrevious`: `reference/riverpod-async.md`.
- Cubit + Bloc full examples, sealed events/states, `on<Event>`, widgets, bloc_test: `reference/bloc.md`.
- Full do/avoid rebuild examples (both), collections, `select`, optimistic update + rollback: `reference/state-updates.md`.
- Riverpod vs Bloc vs provider vs setState, deeper guidance: `reference/choosing.md`.
- Version freshness protocol, package→URL table, reading `pubspec.lock`: `reference/versions.md`.
- `ProviderContainer`/overrides (Riverpod) + `bloc_test` (Bloc): `reference/testing.md`.
