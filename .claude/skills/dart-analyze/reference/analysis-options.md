# Strict analyzer configuration

Create `analysis_options.yaml` at the project root (next to `pubspec.yaml`). Use `package:lints/recommended.yaml` for pure Dart, or `package:flutter_lints/flutter.yaml` (6.0.0) for Flutter. For maximum strictness out of the box, swap the `include:` for `package:very_good_analysis/analysis_options.yaml` (10.3.0). Include **only one** base ruleset, then add overrides below it.

```yaml
include: package:flutter_lints/flutter.yaml   # or package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true       # No implicit downcasts (e.g. List<Object> as List<String>)
    strict-inference: true   # Error when a type silently falls back to dynamic
    strict-raw-types: true   # Require type arguments on generics
  errors:
    invalid_annotation_target: ignore   # noise from freezed/json_serializable
    missing_return: error
    dead_code: warning
  exclude:
    - "**/*.g.dart"          # generated json_serializable
    - "**/*.freezed.dart"    # generated freezed
    - "**/*.mocks.dart"      # generated mockito (if used)
    - "build/**"

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_print
    - avoid_returning_null_for_future
    - cancel_subscriptions
    - close_sinks
    - directives_ordering
    - prefer_const_constructors
    - prefer_const_constructors_in_immutables
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - prefer_single_quotes
    - require_trailing_commas
    - sized_box_for_whitespace
    - sort_child_properties_last
    - unawaited_futures
    - unnecessary_await_in_return
    - unnecessary_late
    - use_build_context_synchronously
    - use_super_parameters
```

## Running the toolchain

```bash
dart analyze --fatal-infos     # fail CI on infos too (flutter analyze --fatal-infos for Flutter)
dart fix --apply               # auto-apply every fixable lint
dart format .                  # canonical formatting; --set-exit-if-changed in CI
```

Order of work: run `dart fix --apply`, then `dart format .`, then `dart analyze --fatal-infos`, then hand-fix what remains. Fix errors before warnings before infos.
