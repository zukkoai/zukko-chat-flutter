# Lint-rule rationale, suppression & DCM

## High-value rules — extended rationale

| Rule | Why it matters |
| --- | --- |
| `always_declare_return_types` | Implicit `dynamic` returns hide type errors and defeat inference downstream |
| `avoid_dynamic_calls` | Calls on `dynamic` skip static checking and dispatch slowly at runtime |
| `avoid_print` | `print` leaks to release logs and has no level/filtering; use a logger |
| `avoid_returning_null_for_future` | Returning `null` instead of a `Future` causes confusing async bugs |
| `cancel_subscriptions` / `close_sinks` | Catch the most common stream/controller memory leaks |
| `directives_ordering` | Deterministic, conflict-free import order; cleaner diffs |
| `prefer_const_constructors` | Enables canonicalization — identical instances shared, fewer allocations |
| `prefer_const_constructors_in_immutables` | Forces const where an immutable class allows it |
| `prefer_final_locals` / `prefer_final_fields` | Prevents accidental reassignment; documents intent |
| `require_trailing_commas` | Stable formatting and cleaner diffs |
| `sized_box_for_whitespace` / `sort_child_properties_last` | Flutter readability and lighter widget trees |
| `unawaited_futures` | Surfaces dropped futures (silent swallowed errors) |
| `unnecessary_await_in_return` / `unnecessary_late` | Removes redundant async/late overhead |
| `use_build_context_synchronously` | Prevents using a `BuildContext` across an `await` gap |
| `use_super_parameters` | `super.key` instead of `super(key: key)` boilerplate |

## Suppressing issues

Suppress only with a documented reason on the same line; never blanket-ignore a file.

```dart
// ignore: avoid_print — CLI tool, stdout is the intended output
print(report);
```

Do not introduce new violations while fixing old ones. After all fixes, re-run `dart analyze --fatal-infos` and confirm `No issues found!`.

## DCM (optional, advanced)

[Dart Code Metrics (dcm.dev)](https://dcm.dev) is an optional commercial analyzer that adds cyclomatic-complexity, anti-pattern, and unused-code rules beyond the core linter. Add it in CI when the team wants deeper metrics:

```bash
dcm analyze lib
```

It complements, rather than replaces, `dart analyze`.
