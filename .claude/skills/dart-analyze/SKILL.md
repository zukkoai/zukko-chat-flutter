---
name: dart-analyze
description: Configures strict analysis_options.yaml and lints, then runs dart analyze, dart fix, and format. Use when setting up Dart static analysis or resolving analyzer warnings, lint errors, and code-quality output.
---

You are a Dart static-analysis expert who configures strict linting and drives the codebase to zero issues.

## When to use
- Setting up or tightening `analysis_options.yaml`.
- Running analyze/fix/format or wiring quality gates into CI.

## What to do
- Put a strict **`analysis_options.yaml`** at the project root: include `package:flutter_lints/flutter.yaml` (Flutter) or `package:lints/recommended.yaml` (pure Dart), enable `strict-casts`/`strict-inference`/`strict-raw-types`.
- **Exclude generated files** from analysis: `**/*.g.dart`, `**/*.freezed.dart`, `**/*.mocks.dart`, `build/**`.
- Run, in order: `dart fix --apply` → `dart format .` → `dart analyze --fatal-infos`, then hand-fix the rest. Fix errors before warnings before infos.
- Suppress only with a documented reason on the same line; never blanket-ignore a file.

```bash
dart fix --apply             # auto-apply every fixable lint
dart format .                # canonical formatting; --set-exit-if-changed in CI
dart analyze --fatal-infos   # fail CI on infos too (flutter analyze for Flutter)
```

## Choosing a base ruleset
Pick **one** base and layer overrides on top — never `include` two.

| Base | Version | When |
|------|---------|------|
| `lints` (`package:lints/recommended.yaml`) | — | **Default for a pure-Dart package** — the official baseline. |
| `flutter_lints` (`package:flutter_lints/flutter.yaml`) | 6.0.0 | Official curated set when the package *is* a Flutter package. |
| `very_good_analysis` | 10.3.0 | Stricter opinionated superset (nearly every useful lint on) from Very Good Ventures — for maximum strictness out of the box. |

## High-value lint rules

| Rule | Why it matters |
| --- | --- |
| `always_declare_return_types` | Implicit `dynamic` returns hide type errors |
| `avoid_dynamic_calls` | Calls on `dynamic` skip static checks and dispatch slowly |
| `avoid_print` | `print` leaks to release logs; use a logger |
| `cancel_subscriptions` / `close_sinks` | Catch stream/controller memory leaks |
| `prefer_const_constructors` | Enables canonicalization and fewer allocations |
| `prefer_final_locals` / `prefer_final_fields` | Prevents accidental reassignment |
| `require_trailing_commas` | Stable formatting, cleaner diffs |
| `unawaited_futures` | Surfaces dropped futures (silent errors) |
| `use_build_context_synchronously` | Prevents `BuildContext` use across an `await` gap |
| `use_super_parameters` | `super.key` instead of `super(key: key)` boilerplate |

## Common mistakes
- Dead code shipped: enable `unused_local_variable`, `unused_import`, `unused_element`, then `dart fix --apply` to strip it.
- Relying on review to catch anti-patterns: the analyzer already finds `dynamic` calls, missing `await`s, leaks — promote the high-value ones to **errors** in the `errors:` block so CI blocks them.

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
- Full strict `analysis_options.yaml` (analyzer block, errors, excludes, complete lint list): read `reference/analysis-options.md`.
- Extended lint-rule rationale, suppression patterns, DCM (optional): read `reference/lint-rules.md`.
- Anti-patterns the analyzer catches (dead code, `dynamic` calls, missing awaits) and how to promote them to errors: read `reference/anti-patterns.md`.
