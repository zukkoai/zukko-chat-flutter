# Three trees, BuildContext, and keys

- [The three trees](#the-three-trees)
- [Element lifecycle and reconciliation](#element-lifecycle-and-reconciliation)
- [BuildContext is the element](#buildcontext-is-the-element)
- [Keys: what they fix](#keys-what-they-fix)
- [LocalKey vs GlobalKey](#localkey-vs-globalkey)
- [When you do / don't need a key](#when-you-do--dont-need-a-key)

## The three trees

Flutter keeps **three parallel trees**, each with a job:

| Tree | Mutability | Role |
|---|---|---|
| **Widget** | immutable, rebuilt freely | *configuration* — a cheap description of what the UI should be |
| **Element** | long-lived, mutable | the *instance* — links a widget to its render object, **holds `State`**, owns identity |
| **RenderObject** | long-lived, mutable | *layout & paint* — does the constraint/size work |

You write widgets; the framework creates an **element** for each and (for render widgets) a **render object**. When you rebuild, you produce new **widget** objects, but the framework tries to **reuse the existing elements and render objects** — that reuse is what makes rebuilds cheap and what preserves `State`.

## Element lifecycle and reconciliation

When a parent rebuilds, for each child slot Flutter compares the **new widget** against the element currently in that slot:

1. **Same `runtimeType` and same `key`** → reuse the element, update it with the new widget (`State` is kept, `didUpdateWidget` fires).
2. **Different type or different key** → deactivate the old element (its `State` is disposed) and inflate a fresh one.

This match is done **position by position among siblings**. So if children **reorder** and carry no keys, slot 0's old element is matched to slot 0's new widget — same type, so it's *reused with the wrong data's state attached*. Keys break the tie by **identity instead of position**.

Element states: *initial → active (mounted) → inactive (removed but possibly reinsertable this frame) → defunct*. A `GlobalKey` lets an element go inactive in one place and reactivate elsewhere — that's how a widget "moves" across the tree without losing `State`.

## BuildContext is the element

`BuildContext` is an interface implemented by `Element`. **The context you get in `build` *is* that widget's element** — its location in the element tree. That's why:

- `Theme.of(context)`, `MediaQuery.of(context)`, `Provider.of(context)` walk **upward from this element** to find the nearest ancestor of the requested type. A context taken from **above** the provider can't see it → null/"No X found in context".
- Calling `.of(context)` in **`initState`** is too early (dependencies aren't wired) and using a context from a different subtree reads the wrong ancestors.
- `context.findRenderObject()` returns this element's render object — valid only **after** layout.

```dart
// AVOID — `context` here is above the Provider that's inside this same build method
Widget build(BuildContext context) {
  final value = Provider.of<Model>(context); // not found
  return Provider<Model>(create: (_) => Model(), child: Text('$value'));
}
// DO — read it in a descendant whose context sits below the Provider (e.g. via Builder/child widget)
```

## Keys: what they fix

A **`Key`** controls element matching during reconciliation. It matters only when **stateful siblings change order or count** (insert/remove/reorder/filter). Without a key, `State` follows **position**; with a stable key, `State` follows **identity**.

```dart
// AVOID — reorder swaps the rows but each TextField keeps the *other* row's controller text
ReorderableListView(
  children: [for (final t in todos) CheckTile(todo: t)],          // no key
  onReorder: onReorder,
)
// AVOID — UniqueKey()/index: rebuilt identity every frame → state is recreated or hops rows
children: [for (final t in todos) CheckTile(key: UniqueKey(), todo: t)],

// DO — stable identity tied to the data
children: [for (final t in todos) CheckTile(key: ValueKey(t.id), todo: t)],
```

Classic symptom: a list of `StatefulWidget` rows (checkboxes, expansion tiles, text fields, per-row animations) where after a swap/delete the **wrong row** is checked/expanded, or scroll/animation state resets.

## LocalKey vs GlobalKey

| Key | Scope | Use for | Cost |
|---|---|---|---|
| `ValueKey(value)` | among siblings | identity from a stable field (`item.id`) | cheap |
| `ObjectKey(obj)` | among siblings | identity by object reference | cheap |
| `UniqueKey()` | among siblings | **force** a fresh element every build | cheap but usually a bug for persisted state |
| `GlobalKey<T>()` | whole app | move a widget across the tree; reach its `State`/`context`/`RenderObject` | **expensive** |

- **`LocalKey`** (`ValueKey`/`ObjectKey`/`UniqueKey`) only needs to be unique **among siblings**. This is the right tool for list reordering.
- **`GlobalKey`** must be unique **across the entire app** and lets you `globalKey.currentState`/`currentContext`. Reuse one in two places in the tree at once → a duplicate-key crash. It re-parents the element (re-running its subtree), so it's not a casual "give it a key" fix — reserve it for `Form`/scaffold access or genuinely moving a subtree.

## When you do / don't need a key

- **Need a key:** reorderable/insertable/removable lists of **stateful** children; preserving a widget's `State` when it moves between parents; swapping two stateful siblings (the `AnimatedSwitcher`/two-children case).
- **Don't need a key:** purely **stateless** rows; lists that only append at the end and never reorder; a single child with no siblings. Adding keys there is harmless noise (or, with `UniqueKey`, actively harmful — it discards reusable state).

For app-level state that should survive *anywhere* (not just position changes), lift it out of the widget into `state-management` rather than leaning on `GlobalKey`.
