# Choosing: Riverpod vs Bloc vs provider vs setState

Pick by the shape of the problem, then **commit to one solution** — never run two side by side. Detect what the project already uses (`pubspec.lock`) and follow it.

## Decision table

| Solution | Best for | Trade-off |
|---|---|---|
| **Riverpod** | Compile-safe DI + reactive derived state, async caching/cancellation, codegen `@riverpod`. Default for new apps. | Codegen + build_runner step; concepts (providers, refs) to learn. |
| **Bloc** | Event-driven flows, explicit traceable transitions, event logging, debounce/concurrency transformers. | More boilerplate (events + handlers). |
| **Cubit** | Simple imperative state: toggles, counters, form fields, simple auth — `emit()` directly. | No event log; promote to Bloc when you need one. |
| **signals** | Fine-grained reactivity — auto-tracked `signal`/`computed`, minimal rebuilds, no codegen (`signals` core + `signals_flutter` binding). | Smaller ecosystem; unopinionated about app architecture/DI. |
| **provider** | Plain `InheritedWidget`-style DI / `ChangeNotifier`; lightweight existing apps. | Manual `notifyListeners`; easy to over-rebuild. |
| **get_it** | Pure service locator / DI, no reactivity. | Not a state container; pair with one of the above. |
| **setState** | Purely-local, ephemeral UI: a toggle in one widget, `AnimationController`, scroll offset. | No sharing, no caching, no testable transitions. |

Rule of thumb: **shared or async → a state container (Riverpod/Bloc/Cubit); local and ephemeral → `setState`.**

## 1. setState for shared/async state — don't

Ad-hoc `setState` for state more than one widget reads, or for the result of an async call, leaves no single source of truth and no caching; siblings can't see it and must be told to refresh.

```dart
// AVOID — feature state trapped in one widget's State
class _CartIconState extends State<CartIcon> {
  List<Item> _items = [];        // siblings can't see this
  bool _loading = false;
  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await repo.fetchCart(); // not cancel-aware, refetched per screen
    setState(() => _loading = false);
  }
}
```

```dart
// DO (Riverpod) — one AsyncNotifier owns the state; any widget watches it
@riverpod
class Cart extends _$Cart {
  @override
  Future<List<Item>> build() => ref.watch(cartRepositoryProvider).fetchCart();
  Future<void> add(Item item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(cartRepositoryProvider).add(item);
      return ref.read(cartRepositoryProvider).fetchCart();
    });
  }
}

class CartIcon extends ConsumerWidget {
  const CartIcon({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((s) => s.value?.length ?? 0));
    return Badge(label: Text('$count'), child: const Icon(Icons.shopping_cart));
  }
}
```

```dart
// DO (Bloc/Cubit) — a Cubit owns the state; any widget reads it via context.select
class CartCubit extends Cubit<CartState> {
  CartCubit(this._repo) : super(const CartLoading());
  final CartRepository _repo;
  Future<void> load() async {
    emit(const CartLoading());
    final result = await _repo.fetchCart();
    if (isClosed) return;
    emit(result.fold(CartLoaded.new, CartError.new));
  }
}

class CartIcon extends StatelessWidget {
  const CartIcon({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context.select<CartCubit, int>(
      (c) => switch (c.state) { CartLoaded(:final items) => items.length, _ => 0 },
    );
    return Badge(label: Text('$count'), child: const Icon(Icons.shopping_cart));
  }
}
```

`setState` is still correct for purely-local, ephemeral UI (a toggle inside one widget, an `AnimationController`).

## 2. No pattern — business state scattered across widgets

Don't spread the same logical state across several `StatefulWidget`s and try to keep them in sync. Centralize.

```dart
// AVOID — each widget owns a copy; they drift out of sync
class FilterBar extends StatefulWidget { /* holds _filter */ }
class ResultList extends StatefulWidget { /* holds its OWN _filter, must be told to refetch */ }
```

```dart
// DO (Riverpod) — one provider; widgets derive from it
@riverpod
class ProductFilter extends _$ProductFilter {
  @override
  Filter build() => const Filter.all();
  void set(Filter f) => state = f;
}

@riverpod
Future<List<Product>> products(Ref ref) {
  final filter = ref.watch(productFilterProvider); // auto-refetch when filter changes
  return ref.watch(productRepositoryProvider).search(filter);
}
```

## 3. Cubit vs Bloc — pick by problem shape

- **Cubit** for simple, imperative state: toggles, counters, form fields, simple auth — call a method, `emit` directly.
- **Bloc** for event-driven flows: a traceable event log, event transformers (debounce, `restartable`), or distinct events feeding one handler.

```dart
// Simple toggle — a Cubit is the right size
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system);
  void toggle() => emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
```

```dart
// Debounced search across distinct events — promote to a Bloc
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._repo) : super(const SearchInitial()) {
    on<QueryChanged>(_onQuery, transformer: restartable()); // cancels stale requests
  }
  final SearchRepository _repo;
  Future<void> _onQuery(QueryChanged e, Emitter<SearchState> emit) async {
    emit(const SearchLoading());
    final result = await _repo.search(e.query);
    emit(result.fold(SearchLoaded.new, SearchError.new));
  }
}
```

Don't reach for a Bloc with events + handlers when a two-line Cubit does the job; don't keep promoting `setState` flags as a feature grows — move to a container before the state spreads.

## 4. Raw FutureBuilder for app data — don't

`FutureBuilder(future: repo.fetch())` recreates the future on **every rebuild**, so it loses loaded state, re-flashes the spinner, and offers no caching, cancellation, or testability.

```dart
// AVOID — new future every build: refires, flickers, no cache, no cancel
FutureBuilder<User>(
  future: repo.fetchUser(id),          // NEW future on every rebuild
  builder: (context, snap) { /* ... */ },
);
```

```dart
// DO (Riverpod) — FutureProvider caches and is cancel-aware
@riverpod
Future<User> user(Ref ref, String id) =>
    ref.watch(userRepositoryProvider).fetchUser(id);

ref.watch(userProvider(id)).when(
  data: (user) => Text(user.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => ErrorView(e),
);
```

```dart
// DO (Bloc) — model the async lifecycle as states, render with BlocBuilder
BlocBuilder<UserCubit, UserState>(
  builder: (context, state) => switch (state) {
    UserLoading() => const CircularProgressIndicator(),
    UserLoaded(:final user) => Text(user.name),
    UserError(:final message) => ErrorView(message),
  },
);
```

`FutureBuilder` is fine for a one-off future you own (e.g. a `showDialog` result), not for repository/app data that should be cached and shared.

## 5. watch/read placement (both)

Using `ref.read` (Riverpod) or `context.read` (Bloc) inside `build` skips the subscription, so the widget never rebuilds — the most common stale-UI cause. Watch in `build` (`ref.watch` / `BlocBuilder` / `context.watch`), read only in callbacks. Full do/avoid: `state-updates.md`.
