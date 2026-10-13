# Full analysis_options.yaml and CI workflow

## Strict analysis_options.yaml

Place this at the project root. It builds on `flutter_lints`, turns on strict type checks, promotes high-value rules to **errors** (so they fail CI), and excludes generated files.

> **Base ruleset:** `flutter_lints` 6.0.0 is the lenient official default. For maximum strictness out of the box, swap the `include:` for `package:very_good_analysis/analysis_options.yaml` (10.3.0); for a pure-Dart package use `package:lints/recommended.yaml`. Include **only one** base, then add overrides below it.

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true         # no implicit dynamic -> T casts
    strict-inference: true     # fail when a type can't be inferred
    strict-raw-types: true     # no raw List/Map/Future without type args
  errors:
    # promote correctness rules from warning -> error (break the build)
    invalid_annotation_target: ignore        # noise from json_serializable/freezed
    use_build_context_synchronously: error
    avoid_dynamic_calls: error
    cancel_subscriptions: error
    close_sinks: error
    unawaited_futures: error
    always_use_package_imports: error
    prefer_const_constructors: warning
  exclude:
    - "**.g.dart"
    - "**.freezed.dart"
    - "**.gr.dart"
    - "**.mocks.dart"
    - "**.config.dart"
    - "lib/**/l10n/**"            # generated localizations
    - "lib/generated/**"
    - "build/**"

linter:
  rules:
    use_key_in_widget_constructors: true
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_const_literals_to_create_immutables: true
    avoid_unnecessary_containers: true
    sized_box_for_whitespace: true
    use_colored_box: true
    use_decorated_box: true
    avoid_print: true
    prefer_single_quotes: true
    require_trailing_commas: true
    sort_child_properties_last: true
    avoid_redundant_argument_values: true
    unnecessary_await_in_return: true
    use_super_parameters: true
    directives_ordering: true
```

## Daily commands

| Command | Purpose |
|---------|---------|
| `flutter analyze` | Run the analyzer; exits non-zero on issues. |
| `flutter analyze --fatal-infos` | Treat info-level lints as failures (use in CI). |
| `dart fix --dry-run` | Preview automatic fixes for fixable lints. |
| `dart fix --apply` | Apply all auto-fixes (const insertion, super params, etc.). |
| `dart format .` | Format the whole tree (Dart's canonical formatter). |
| `dart format --output=none --set-exit-if-changed .` | Verify formatting in CI without rewriting files. |

Run `dart fix --apply` after enabling new lints to auto-migrate most of the codebase.

## Wire it into CI

```yaml
# .github/workflows/analyze.yml
name: analyze
on: [push, pull_request]
jobs:
  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze --fatal-infos --fatal-warnings
```

Order matters: format check, then analyze. Both must pass before tests run.

## Checklist

- [ ] `analysis_options.yaml` includes `flutter_lints` + strict language modes.
- [ ] Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`, l10n) excluded.
- [ ] `use_build_context_synchronously` is an error; all async gaps guarded with `mounted`.
- [ ] Stream/sink leak rules (`cancel_subscriptions`, `close_sinks`) enabled.
- [ ] CI runs `dart format` check + `flutter analyze --fatal-infos`.
- [ ] `dart fix --apply` run after any lint-config change.
