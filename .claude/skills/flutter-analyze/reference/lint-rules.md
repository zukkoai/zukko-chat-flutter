# High-value Flutter lint rules (and DCM)

## Curated rule table

| Rule | Why it matters |
|------|----------------|
| `use_build_context_synchronously` | Catches `BuildContext` used after an `await` — the #1 source of "looking up a deactivated widget" crashes. |
| `use_key_in_widget_constructors` | Forces `Key? key` so widgets behave correctly in lists and reuse. |
| `prefer_const_constructors` | `const` widgets skip rebuilds — direct performance win (see **optimization** skill). |
| `prefer_const_literals_to_create_immutables` | Makes `const [ ... ]` children const too, extending the benefit. |
| `avoid_unnecessary_containers` | A bare `Container` wrapping one child adds a layout node for nothing. |
| `sized_box_for_whitespace` | `SizedBox` (const, cheap) instead of `Container` for spacing. |
| `use_colored_box` / `use_decorated_box` | Lighter than `Container` when you only need color/decoration. |
| `cancel_subscriptions` / `close_sinks` | Prevents memory leaks from un-cancelled streams and unclosed controllers. |
| `unawaited_futures` | Surfaces fire-and-forget futures that silently swallow errors. |
| `avoid_dynamic_calls` | Stops `dynamic` from defeating the type system at runtime. |
| `sort_child_properties_last` | Keeps `child:`/`children:` last for readable widget trees. |
| `use_super_parameters` | Modern `super.key` syntax; cleaner constructors. |
| `require_trailing_commas` | Stable formatting and cleaner diffs. |
| `directives_ordering` | Consistent, sorted imports. |
| `prefer_single_quotes` / `avoid_print` | Style consistency; no stray `print` in production. |

## Severity strategy

- **Promote to `error`** the correctness/leak/crash rules: `use_build_context_synchronously`, `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`, `unawaited_futures`. These should break CI.
- Keep style/perf rules (`prefer_const_constructors`, container rules) as warnings/infos and run CI with `--fatal-infos` to enforce them without conflating them with crash bugs.

## Optional advanced tooling: DCM

[DCM (Dart Code Metrics)](https://dcm.dev) adds ~200 extra rules, anti-pattern detection, cyclomatic-complexity limits, unused-code finding, and widget-specific checks beyond `flutter_lints`. Adopt it on larger teams when the default lints feel insufficient; configure it under a `dart_code_metrics:` block and run `dcm analyze lib`. It is optional — a strict `flutter_lints` baseline already covers the essentials.
