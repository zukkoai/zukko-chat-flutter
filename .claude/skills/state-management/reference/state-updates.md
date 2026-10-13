# State updates that actually rebuild the UI (Riverpod + Bloc)

The #1 stale-UI bug: data changes but the UI doesn't. Flutter rebuilds a widget only when the value it watches is a **NEW object that is `!=` the previous one**. Mutating the existing state in place leaves the reference unchanged, so `==` reports "no change" and nothing rebuilds. In Bloc/Cubit it's worse: **`emit` is silently dropped when `newState == state`.**

---

# Riverpod

## Use a value-equality state class

```dart
@freezed
abstract class CartState with _$CartState {
  const factory CartState({
    @Default([]) List<Item> items,
    @Default(false) bool checkingOut,
  }) = _CartState;
}
```

freezed (or an Equatable class) gives `==`, `hashCode`, and `copyWith`. Equal states now skip rebuilds; changed states actually differ — which is exactly why creating a correct NEW instance matters.

## Scalar / object fields — copyWith, never mutate

```dart
@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  CartState build() => const CartState();

  // avoid — mutating the existing object; same reference, no rebuild
  // (and freezed/Equatable fields are final, so you can't reassign them anyway)

  // do — new instance via copyWith
  void startCheckout() => state = state.copyWith(checkingOut: true);
}
```

## Collections — build a NEW collection

The most common stale-UI bug. A `List` is `==` only to itself, so adding to it and reassigning the same reference changes nothing.

```dart
// AVOID — same List reference; no rebuild even though contents changed
void addBroken(Item item) {
  state.items.add(item);                       // mutates in place
  state = state.copyWith(items: state.items);  // same reference -> == -> no rebuild
}

// DO — new List every time
void add(Item item) =>
    state = state.copyWith(items: [...state.items, item]);

void remove(String id) =>
    state = state.copyWith(items: state.items.where((i) => i.id != id).toList());

void updateQty(String id, int qty) => state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id == id) i.copyWith(qty: qty) else i,
      ],
    );
```

Same rule for `Map` and `Set`: `{...state.map, key: value}`, `{...state.set, x}`.

## AsyncNotifier — new AsyncData / guard

```dart
state = AsyncData([...current, newItem]);             // new AsyncData + new list
state = await AsyncValue.guard(() => _repo.fetchAll()); // new AsyncValue
```

Never mutate the list inside the current `AsyncData` and reassign it.

## Optimistic update + rollback (Riverpod)

```dart
Future<void> toggle(String id) async {
  final current = state.value ?? [];
  state = AsyncData([                              // optimistic — new list, new item
    for (final t in current)
      if (t.id == id) t.copyWith(done: !t.done) else t,
  ]);
  final result = await AsyncValue.guard(() => _repo.toggle(id));
  if (result.hasError) state = AsyncData(current); // rollback to captured snapshot
}
```

## Subscribe in build with watch, not read

```dart
final cart = ref.read(cartNotifierProvider);  // AVOID — does not subscribe; UI never updates
final cart = ref.watch(cartNotifierProvider); // DO — subscribes the widget to changes
```

## Slice rebuilds with select

```dart
final count = ref.watch(cartNotifierProvider.select((s) => s.items.length));
// this widget rebuilds only when items.length changes
```

`select`'s comparison is `==`, so the selected slice must also have value equality.

## autoDispose: guard async state assignment

An autoDispose provider can be disposed (and its notifier recreated) while an `await` is in flight. `AsyncValue.guard` is safe; before a raw `state = ...` after an await, gate on `if (!ref.mounted) return;`. Re-read fresh state after the await and let guard handle it, or check `ref.mounted` before assigning.

---

# Bloc / Cubit

## Sealed states + Equatable (props must cover every field)

```dart
final class TodoLoaded extends TodoState {
  const TodoLoaded(this.todos, {this.filter = Filter.all});
  final List<Todo> todos;
  final Filter filter;
  @override
  List<Object?> get props => [todos, filter]; // EVERY field, or changes are invisible
}
```

Omit `filter` from `props` and a filter change compares equal → emit dropped → UI never updates.

## Scalar/object change — new instance, never mutate

```dart
// AVOID — mutating the current state's field (fields are final anyway), no new instance
// DO — emit a new instance (copyWith on a data state, or a fresh sealed instance)
final current = state as TodoLoaded;
emit(TodoLoaded(current.todos, filter: Filter.active));
```

## Collections — build a NEW collection

The classic dropped-emit bug:

```dart
final current = state as TodoLoaded;

// AVOID — same List reference; newState == state -> emit IGNORED -> UI stale
current.todos.add(todo);
emit(TodoLoaded(current.todos));

// DO — new List every time
emit(TodoLoaded([...current.todos, todo]));                          // add
emit(TodoLoaded(current.todos.where((t) => t.id != id).toList()));    // remove
emit(TodoLoaded([                                                     // update item
  for (final t in current.todos)
    if (t.id == id) t.copyWith(done: !t.done) else t,
]));
```

Same for `Map`/`Set`: `{...current.map, k: v}`, `{...current.set, x}`.

## Optimistic update + rollback (Bloc)

```dart
Future<void> _onToggle(TodoToggled e, Emitter<TodoState> emit) async {
  final current = state;
  if (current is! TodoLoaded) return;
  final optimistic = [                         // new list, new item
    for (final t in current.todos)
      if (t.id == e.id) t.copyWith(done: !t.done) else t,
  ];
  emit(TodoLoaded(optimistic));
  final result = await _repo.toggle(e.id);
  if (emit.isDone) return;
  if (result.isFailure) emit(current);         // rollback to the captured state
}
```

## Async / stream emits — guard

A bloc can be closed mid-`await`.

```dart
// Cubit
Future<void> load() async {
  emit(const TodoLoading());
  final data = await _repo.fetchAll();
  if (isClosed) return;        // guard before emit
  emit(TodoLoaded(data));
}
```

```dart
// Bloc handler — emit throws after the handler returns; for streams check isDone
on<Subscribed>((e, emit) async {
  await for (final batch in _repo.stream) {
    if (emit.isDone) break;    // emitter closed
    emit(TodoLoaded(batch));
  }
});
```

## Side effects belong in BlocListener

Navigation, snackbars, and dialogs go in `BlocListener`/`listener`, NEVER in `BlocBuilder` (builders run many times). See `bloc.md` Widgets.

---

## Verify state→UI checklist (both)
1. NEW state instance assigned (`copyWith` / new `AsyncData`) or emitted (`copyWith` / fresh sealed instance), not a mutated field?
2. NEW collection built (spread / `.where().toList()` / collection-for), not `.add`/`.remove` on the reused list?
3. Equatable `props` / freezed fields cover ALL state fields?
4. UI watches in `build` — `ref.watch` (Riverpod) or `BlocBuilder`/`context.watch` (Bloc), not `read`?
5. Async guarded — Riverpod (`AsyncValue.guard` / `if (!ref.mounted)`) / `isClosed` (Cubit) / `emit.isDone` (Bloc streams)?
6. Loading and error states rendered, not just the data state?
