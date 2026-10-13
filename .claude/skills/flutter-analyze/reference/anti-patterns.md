# Analysis anti-patterns

Do/avoid examples for the bugs static analysis is meant to stop. The deep dive on every async-gap variant is in `reference/context-async-gaps.md`; this file collects the lifecycle and dead-code mistakes with runnable do/avoid pairs.

## 1. `BuildContext` across async gaps

After an `await` the widget may be disposed; touching `context` then throws "looking up a deactivated widget's ancestor". `use_build_context_synchronously: error` flags every unguarded use.

```dart
// avoid: context used after await, with no mounted guard
Future<void> _submit() async {
  await repository.save(form);
  Navigator.of(context).pop();                 // context may be dead
  ScaffoldMessenger.of(context)                // and again
      .showSnackBar(const SnackBar(content: Text('Saved')));
}
```

```dart
// do: re-check after EACH await; capture messenger before the gap if needed
Future<void> _submit() async {
  final messenger = ScaffoldMessenger.of(context); // capture while alive
  await repository.save(form);
  if (!mounted) return;                            // State.mounted
  Navigator.of(context).pop();
  messenger.showSnackBar(const SnackBar(content: Text('Saved')));
}
```

In a helper that takes a `BuildContext`, guard with `context.mounted`:

```dart
// avoid
Future<void> confirmDelete(BuildContext context, Repo repo) async {
  await repo.delete();
  Navigator.of(context).pop();                 // unguarded
}

// do
Future<void> confirmDelete(BuildContext context, Repo repo) async {
  await repo.delete();
  if (!context.mounted) return;
  Navigator.of(context).pop();
}
```

Re-check after *every* await, not just the first — see `reference/context-async-gaps.md` for the multi-await and captured-context traps.

## 2. Synchronous context work in `initState`

`initState` runs before the first frame, so `MediaQuery`/`ScaffoldMessenger`/`showDialog` aren't safely available yet. Defer to after the frame.

```dart
// avoid: inherited-widget lookup and dialog in initState
@override
void initState() {
  super.initState();
  final width = MediaQuery.of(context).size.width; // may throw / be wrong
  showDialog(context: context, builder: (_) => const Welcome()); // no frame yet
}
```

```dart
// do: defer until the first frame is mounted, then guard
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => const Welcome());
  });
}
```

For one-time async loading, kick off the future in `initState` but only touch `context` after awaiting + a `mounted` check:

```dart
// do: async init pattern
@override
void initState() {
  super.initState();
  unawaited(_load()); // unawaited_futures stays happy
}

Future<void> _load() async {
  final data = await repository.fetch();
  if (!mounted) return;
  setState(() => _data = data);
}
```

## 3. Dead / unused code

Unreferenced fields, imports, locals, and elements rot and hide real bugs. Enable the `unused_*` lints and let `dart fix` remove them.

```dart
// avoid: dead imports, unused field, unreachable code
import 'dart:math';            // unused_import
import 'legacy_helper.dart';   // unused_import

class CartService {
  final _logger = Logger();    // unused_field — never read

  double total(List<Item> items) {
    return items.fold(0, (s, i) => s + i.price);
    print('done');             // dead_code — after return
  }
}
```

```dart
// do: remove what nothing references; enable the lints so CI catches regressions
class CartService {
  double total(List<Item> items) =>
      items.fold(0, (s, i) => s + i.price);
}
```

```yaml
# analysis_options.yaml
linter:
  rules:
    unused_import: true
    unused_local_variable: true
    unused_field: true
    unused_element: true
    dead_code: true
```

Then sweep automatically: `dart fix --apply` (removes unused imports and other fixable lint hits), and `flutter analyze --fatal-infos --fatal-warnings` in CI so dead code never merges.
