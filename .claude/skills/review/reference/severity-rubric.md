# Severity rubric + example report

How to classify each "no" from `reference/checklist.md`, and what a finished
review looks like. The guiding question for every finding: **what is the worst
plausible outcome if this ships?**

## The three buckets

### Blocking — must fix before merge
The change is unsafe, incorrect, or insecure. Ship it and a user (or attacker)
is harmed.

- **Crashes / will crash:** unjustified `!`, `late` read before init, unguarded
  cast, index/`null` deref on a fallible path.
- **Memory leak:** any controller / `AnimationController` / `StreamSubscription`
  / `Timer` / listener created and never disposed/cancelled/removed.
- **Wrong behavior:** the code does not do what the change claims (off-by-one,
  inverted condition, wrong field, race).
- **Security:** hardcoded secret / API key / token / password; secret or PII
  written to logs, `print`, or crash reports.
- **State → UI doesn't update:** state mutated in place, same collection reused,
  `props` missing a field, `ref.read` in `build` — UI shows stale data.
- **Missing error handling:** a fallible call (network/IO/parse) with no handling
  on its path, or an empty `catch {}` that swallows the error.
- **`BuildContext` across an async gap** with no `mounted`/`context.mounted` guard.

### Should-fix — fix before merge unless explicitly deferred
Not a crash today, but an anti-pattern, missing safety net, or maintainability /
perf debt that will bite.

- Anti-patterns: logic in `build()`, `Widget _buildX()` helper methods,
  `SingleChildScrollView` + `Column` for long lists, `FutureBuilder(future:
  repo.fetch())` in `build`.
- Missing **tests** for new logic/widgets, or tests that only assert "no throw".
- SRP / god class; tight coupling / `new`-ed concretes instead of injected DI.
- Performance: missing `const`, over-broad rebuilds, allocation in `build`.
- `dynamic` / loose typing where a precise type fits.

### Nit — optional, group and keep brief
Real but non-urgent. Naming, formatting, magic numbers, dead code, minor style.
List them compactly; never let nits crowd out the blocking items.

## Escalation rule
Theme defaults in the checklist are a starting point, not the verdict. **Escalate**
when the worst outcome is worse than the default: a "magic number" that's a
hardcoded API key is **Blocking**, not Nit. **Don't inflate**: a missing `const`
is Should-fix/Nit, never Blocking. When unsure between two buckets, pick the
higher one and say why in one line.

## Verdict line
- **Changes needed** if there is ≥1 Blocking or unaddressed Should-fix.
- **Approve** (or "Approve with nits") if only nits remain.
- State the verdict first, with the count: `Changes needed — 2 blocking, 1 should-fix.`

## Example review report

> **Changes needed — 2 blocking, 1 should-fix, 1 nit.**
>
> **Blocking**
> - `lib/features/auth/login_view_model.dart:34` — **secret hardcoded**: `apiKey = 'sk_live_...'` in source. Move to `--dart-define` / `Env.apiKey`; rotate the leaked key. (see `flutter`)
> - `lib/features/cart/cart_notifier.dart:52` — **state→UI won't update**: `state.items.add(item)` mutates and reuses the same list. Emit a new list: `state = state.copyWith(items: [...state.items, item]);` (see `state-management`)
>
> **Should-fix**
> - `lib/features/cart/cart_view.dart:18` — **logic in `build()`**: `repo.fetchTotals()` called inside `build`, refires every rebuild. Move to a `FutureProvider`/`AsyncNotifier`. (see `state-management`)
>
> **Nit**
> - `lib/features/cart/cart_view.dart:40` — **magic number** `72`; name it `kRowHeight` and pass as `itemExtent`.
>
> **Definition-of-done check**
> - Compiles: yes · `flutter analyze`: clean · `dart format`: applied
> - Tests: **missing** for `cart_notifier` add/remove — add `bloc_test`/provider tests
> - State→UI: **fails** until the new-list fix lands
> - Disposal: ok (no new controllers) · Secrets: **fails** until the key is removed
