# The use_build_context_synchronously pitfall

After any `await`, the widget may have been disposed and its `BuildContext` is no longer valid. Touching it then throws "looking up a deactivated widget's ancestor". Guard with `mounted` (in a `State`) or `context.mounted` (anywhere with a context).

## Avoid vs do

```dart
// avoid: context used across an async gap
Future<void> save() async {
  await repository.save(data);
  Navigator.of(context).pop();          // context may be dead
}

// do: check mounted before touching context
Future<void> save() async {
  await repository.save(data);
  if (!context.mounted) return;          // inside a State: use `if (!mounted) return;`
  Navigator.of(context).pop();
}
```

## In a State vs a standalone function

```dart
// Inside a State<T>: prefer the State's own `mounted`.
class _FormState extends State<Form> {
  Future<void> _submit() async {
    final ok = await _api.submit();
    if (!mounted) return;                 // State.mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Saved' : 'Failed')),
    );
  }
}

// In a helper that receives a BuildContext: use context.mounted.
Future<void> confirmAndDelete(BuildContext context, Repo repo) async {
  await repo.delete();
  if (!context.mounted) return;
  Navigator.of(context).pop();
}
```

## Common traps

- **Multiple awaits:** re-check `mounted`/`context.mounted` after *each* `await`, not just the first.
- **Captured context in callbacks:** a context captured before an `await` inside a builder/closure is just as unsafe — guard at the point of use.
- **Capturing context-derived objects early:** read `Navigator.of(context)` / `ScaffoldMessenger.of(context)` into a local *before* the `await` if you must, then you only depend on the captured object — but you still must not assume the widget is alive for UI like `showDialog`.

The **analyze** skill sets `use_build_context_synchronously: error` so the analyzer flags every unguarded gap at build time.
