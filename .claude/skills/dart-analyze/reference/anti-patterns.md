# Analyzer anti-patterns: do / avoid

The analyzer is your first line against anti-patterns — most don't need a human
reviewer to spot. Turn the relevant rules on, then promote the ones that should
block a build from warnings to errors. (Dart 3.12.)

## 17. Dead code
Unused locals, imports, and private members rot in place. Enable the rules,
then let `dart fix` delete most of them automatically.

```yaml
# analysis_options.yaml
linter:
  rules:
    unused_local_variable: true
    unused_import: true
    unused_element: true   # unused private classes/methods/fields
    dead_code: true        # unreachable statements
```

```bash
dart fix --apply   # auto-removes unused imports and many dead-code findings
dart analyze --fatal-infos
```

```dart
// Avoid: analyzer reports unused_import + unused_local_variable + unused_element.
import 'dart:convert'; // never referenced
int sum(List<int> xs) {
  final n = xs.length;   // computed, never used
  return xs.fold(0, (a, b) => a + b);
}
void _unusedHelper() {}  // never called

// Do: after `dart fix --apply`, only live code remains.
int sum(List<int> xs) => xs.fold(0, (a, b) => a + b);
```

## Promote high-value anti-patterns to errors
A warning is easy to ignore; an error fails the build. Put the rules that map to
real bugs in the analyzer's `errors:` block so they can't be merged. The
analyzer catches far more than dead code — `dynamic` calls, missing `await`s,
context-across-await, leaks — promote those that matter.

```yaml
# analysis_options.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    # anti-patterns elevated from warning/info to error:
    avoid_dynamic_calls: error            # dynamic dispatch bypasses checks
    unawaited_futures: error              # dropped futures = silent failures
    use_build_context_synchronously: error # context used across an await gap
    cancel_subscriptions: error           # leaked StreamSubscriptions
    close_sinks: error                    # leaked StreamControllers
    unused_import: error
    dead_code: error

linter:
  rules:
    avoid_dynamic_calls: true
    unawaited_futures: true
    use_build_context_synchronously: true
    cancel_subscriptions: true
    close_sinks: true
```

```bash
# CI gate — any promoted anti-pattern now fails the run.
dart analyze --fatal-infos --fatal-warnings
```

Notes:
- Promote gradually on an existing codebase: fix the current findings first,
  then flip each rule to `error` so it can't regress.
- Suppress only with a documented `// ignore: rule_name — reason` on the same
  line; never blanket-ignore a whole file.
