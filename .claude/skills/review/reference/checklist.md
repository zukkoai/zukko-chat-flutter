# Flutter/Dart review checklist

The core of the review. Walk every theme; each item is a **yes/no question** —
answer "yes" if the code is correct, "no" if it's a finding. A "no" becomes a
report item at the severity noted next to its theme (and refined by the rubric in
`reference/severity-rubric.md`). The numbers in parentheses map to the repo's
documented anti-patterns; the deep do/avoid for each lives in the named skill's
`reference/anti-patterns.md`.

> Default severity is a guide, not a rule: classify by worst plausible outcome
> (see `reference/severity-rubric.md`). A "no" that can crash, leak, ship a
> secret, or show stale UI is **Blocking** regardless of its theme's default.

## Correctness & safety — usually Blocking

### Null safety & `!` (#1 — `dart`)
- [ ] No `!` (bang) used just to silence the analyzer — every `!` is provably non-null?
- [ ] Nullables handled with `?.` / `??` / `??=` / null-check promotion, not forced?
- [ ] `late` fields are guaranteed to be written before any read (no `LateInitializationError` path)? (#23)

### `BuildContext` across async gaps (#2 — `flutter-analyze`)
- [ ] `mounted` (State) / `context.mounted` re-checked after **every** `await` before touching `context`?
- [ ] No `BuildContext` stored in a long-lived object (notifier, repo, static)?
- [ ] No inherited-widget lookup / dialog in `initState` before the first frame?

### Async error handling & swallowed errors (— `error-handling`)
- [ ] Every fallible call (network, IO, parse) has error handling on its path? (no-error-handling)
- [ ] No empty `catch {}` / `catch (_) {}` that swallows the error silently? (swallowed errors)
- [ ] Errors cross layers as `Result`/`Failure` (or are surfaced), not lost or rethrown as raw `Exception`?
- [ ] In a `Notifier`/`AsyncNotifier`, mutations are wrapped in `AsyncValue.guard` (or equivalent) so errors land in state?

### State → UI updates (the #1 bug — `state-management`)
- [ ] State change emits/assigns a **new immutable instance** (`copyWith`/new state), never mutates `state.field` in place?
- [ ] Collections rebuilt as a **new** list/map/set (`[...old, x]`), never `.add`/`.remove` on the reused reference?
- [ ] Equatable/freezed `props` cover **all** fields (no field silently excluded from equality)?
- [ ] Widget subscribes with `ref.watch` (in `build`) / `BlocBuilder` — not `ref.read` in `build`?
- [ ] Loading **and** error states are rendered (`AsyncValue.when` / state union), not just data?

### Security: config & secrets (— `flutter`)
- [ ] No hardcoded API keys, tokens, passwords, or secrets in source?
- [ ] No hardcoded URLs/endpoints/config literals — config via `Env` / `--dart-define`?
- [ ] No secrets, tokens, or PII written to logs / `print` / crash reports?

## Lifecycle & memory — usually Blocking

### Controller / subscription / timer disposal (#5 / #11 — `flutter-optimization`)
- [ ] Every `TextEditingController` / `ScrollController` / `AnimationController` is `dispose()`d?
- [ ] Every `StreamSubscription` is `cancel()`ed and every `StreamController` `close()`d?
- [ ] Every `Timer` / `Timer.periodic` is cancelled?
- [ ] Every added listener (`addListener`, `ValueNotifier`, `Animation`) is removed?
- [ ] Resources are created in `initState` / `ref.onDispose`-guarded `build`, **not** in `build()`?

## Design & performance — usually Should-fix

### `setState` / rebuild scope (#3 / #8 — `flutter-optimization`)
- [ ] Mutable state lives in the **smallest** widget that needs it (no page-level `setState` for a leaf change)?
- [ ] No whole-tree rebuild for a local change (uses `ValueListenableBuilder` / `select` / `buildWhen` where apt)?

### Logic in `build()` (— `flutter`)
- [ ] `build()` is pure — no I/O, HTTP, parsing, heavy computation, or business logic inside it?
- [ ] No object allocation in `build()` that could be hoisted to `const` / `initState` / a field?

### Stateless vs Stateful & `const` (#7 / #26 / #27 — `flutter-optimization`)
- [ ] `StatefulWidget` only where something actually changes over the widget's life (else `StatelessWidget`)?
- [ ] `const` constructors and `const` children used wherever values are compile-time constants?

### Lists: builder vs scroll-view (#12 — `flutter-optimization`)
- [ ] Long/unbounded lists use `ListView.builder` / `SliverList.builder`, not `SingleChildScrollView` + `Column`/`.map().toList()`?
- [ ] Stateful list items have stable `Key`s; fixed-height rows set `itemExtent`?

### Return-widget-from-method (#13 — `flutter-optimization`)
- [ ] UI extracted into real `const StatelessWidget`s, not `Widget _buildHeader()` helper methods?

### `FutureBuilder` misuse (— `state-management`)
- [ ] No `FutureBuilder(future: repo.fetch())` created in `build` (refires every rebuild) — uses a provider / cached future / `AsyncNotifier`?

## Structure & maintainability — Should-fix / Nit

### SRP / god class (#18 — `dart`)
- [ ] Each class has **one** reason to change (no class doing UI + business + data)?
- [ ] One public class per file; file name = `snake_case` of the class?

### Coupling & DI (— `flutter`)
- [ ] Widgets/ViewModels depend on **interfaces injected via DI**, not `new`-ing concrete services/repos?
- [ ] Domain layer has no `package:flutter` / `dart:io` / JSON imports (dependencies point inward)?

### Typing (#24 — `dart`)
- [ ] No `dynamic` / raw generics where a precise type or bounded generic would work?
- [ ] Public APIs have explicit return and parameter types?

### DRY / copy-paste (#14 — `dart`)
- [ ] No duplicated logic that should be extracted to a shared function/widget/mixin?

### Magic numbers / strings (#16 — `dart`)
- [ ] Bare numeric/string literals named as constants or modeled as an `enum`?

### Dead code (#17 / #3-analyze — `dart` / `flutter-analyze`)
- [ ] No unused imports, fields, locals, private methods, or unreachable code?

### Tests (— `flutter-test` / `dart-test`)
- [ ] New logic / widgets / view models have tests?
- [ ] Tests assert **behavior** (state→UI, error paths, edge cases), not just "doesn't throw"?
- [ ] Tests follow the project's framework/style (`mocktail`, `bloc_test`, golden, etc.)?

### Style & naming — Nit
- [ ] Names follow Dart conventions (`lowerCamelCase`, `UpperCamelCase`, `_private`) and read clearly?
- [ ] `dart format` applied; analyzer clean (no new infos/warnings)?
