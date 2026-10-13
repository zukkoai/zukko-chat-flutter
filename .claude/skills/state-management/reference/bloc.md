# flutter_bloc — Cubit, Bloc, sealed states/events, widgets, testing

Idiomatic flutter_bloc using Cubit and Bloc with Dart 3 sealed classes.

## Setup

```yaml
dependencies: { flutter_bloc: ^9.1.1, equatable: ^2.0.0 }
dev_dependencies: { bloc_test: ^10.0.0 }
```

Prefer `flutter pub add flutter_bloc equatable` (+ `dev:bloc_test`) for the latest compatible versions.

For state that must survive app restarts, use **`hydrated_bloc`** — `HydratedCubit`/`HydratedBloc` persist state automatically via generated `toJson`/`fromJson` (set up `HydratedBloc.storage` in `main`).

## Cubit vs Bloc

| | Cubit | Bloc |
|---|-------|------|
| Style | Imperative — call methods, `emit()` directly | Event-driven — `add(event)`, handled by `on<Event>` |
| Use for | Simple state (toggles, counters, form fields, simple auth) | Complex flows, traceable transitions, debounce/concurrency control |
| Boilerplate | Low | Higher (events + handlers) |

Start with a Cubit; promote to a Bloc when you need an event log or event transformers.

## Sealed states & events (Dart 3)
Sealed classes give **exhaustive `switch`** — the compiler forces every case. Equatable gives value equality (required: see state-updates.md).

```dart
sealed class TodoState extends Equatable {
  const TodoState();
  @override
  List<Object?> get props => [];
}
final class TodoInitial extends TodoState { const TodoInitial(); }
final class TodoLoading extends TodoState { const TodoLoading(); }
final class TodoLoaded extends TodoState {
  const TodoLoaded(this.todos, {this.filter = Filter.all});
  final List<Todo> todos;
  final Filter filter;
  @override
  List<Object?> get props => [todos, filter]; // EVERY field, or changes are invisible
}
final class TodoError extends TodoState {
  const TodoError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
```

- **Sealed** → exhaustive `switch` in the builder; the compiler forces every case.
- **Equatable `props` must list every field.** Omit `filter` and a filter change compares equal → emit dropped → UI never updates.

## Cubit — full examples

A Cubit is imperative: call methods, `emit()` a new state directly.

### Minimal counter

```dart
final class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1); // new value -> rebuild
  void decrement() => emit(state - 1);
}
```

`int` has value equality, so `emit(state + 1)` is always `!= state`.

### Auth cubit with sealed state + repository

```dart
sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}
final class AuthInitial extends AuthState { const AuthInitial(); }
final class AuthLoading extends AuthState { const AuthLoading(); }
final class AuthLoaded extends AuthState {
  const AuthLoaded(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}
final class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

final class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthInitial());
  final AuthRepository _repo;

  Future<void> login(String email, String pw) async {
    emit(const AuthLoading());
    final result = await _repo.login(email, pw);
    if (isClosed) return; // async guard
    switch (result) {
      case Success(:final value): emit(AuthLoaded(value));
      case Failure(:final failure): emit(AuthError(failure.message));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    if (isClosed) return;
    emit(const AuthInitial());
  }
}
```

Notes:
- **`if (isClosed) return;`** after every `await` — the cubit may have been closed while the request was in flight.
- Inject `AuthRepository` through the constructor; never construct it inside the cubit.
- Each branch emits a **new** sealed state instance.

### Cubit holding a data class (copyWith)

```dart
final class FormCubit extends Cubit<FormState> {
  FormCubit() : super(const FormState());

  void setEmail(String v) => emit(state.copyWith(email: v)); // new instance
  void setPassword(String v) => emit(state.copyWith(password: v));
}
```

Use `copyWith` so each emit is a new instance; the missing `==` would otherwise drop the emit.

### Cubit cleanup

```dart
final class FeedCubit extends Cubit<FeedState> {
  FeedCubit(this._repo) : super(const FeedInitial()) {
    _sub = _repo.stream.listen((d) {
      if (!isClosed) emit(FeedLoaded(d));
    });
  }
  final FeedRepository _repo;
  late final StreamSubscription _sub;

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
```

## Bloc — events, on<Event>, transformers

A Bloc is event-driven: dispatch with `add(event)`, handle in `on<Event>` registered in the constructor.

### Sealed events + handlers

```dart
sealed class TodoEvent {
  const TodoEvent();
}
final class TodoStarted extends TodoEvent { const TodoStarted(); }
final class TodoAdded extends TodoEvent {
  const TodoAdded(this.title);
  final String title;
}
final class TodoDeleted extends TodoEvent {
  const TodoDeleted(this.id);
  final String id;
}

final class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc(this._repo) : super(const TodoLoading()) {
    on<TodoStarted>(_onStarted);
    on<TodoAdded>(_onAdded);
    on<TodoDeleted>(_onDeleted);
  }
  final TodoRepository _repo;

  Future<void> _onStarted(TodoStarted e, Emitter<TodoState> emit) async {
    emit(const TodoLoading());
    final result = await _repo.fetchAll();
    switch (result) {
      case Success(:final value): emit(TodoLoaded(value));
      case Failure(:final failure): emit(TodoError(failure.message));
    }
  }

  Future<void> _onAdded(TodoAdded e, Emitter<TodoState> emit) async {
    final current = state;
    if (current is! TodoLoaded) return;
    await _repo.create(e.title);
    final fresh = await _repo.fetchAll();
    if (fresh case Success(:final value)) emit(TodoLoaded(value)); // new instance
  }

  Future<void> _onDeleted(TodoDeleted e, Emitter<TodoState> emit) async {
    final current = state;
    if (current is! TodoLoaded) return;
    emit(TodoLoaded(current.todos.where((t) => t.id != e.id).toList())); // NEW list
    await _repo.delete(e.id);
  }
}
```

Rules:
- **Register every event** with `on<Event>(handler)`.
- Inject repositories through the constructor.
- Each `emit` is a **new** state instance; collection updates build a **new** list.
- `emit` inside `on<Event>` throws if called after the handler returns; for long-running work check `emit.isDone`.

### Event transformers (concurrency control)

```dart
import 'package:bloc_concurrency/bloc_concurrency.dart';

on<SearchChanged>(
  _onSearch,
  transformer: debounce(const Duration(milliseconds: 300)),
);

Transformer<E> debounce<E>(Duration d) =>
    (events, mapper) => events.debounce(d).switchMap(mapper);
```

Built-ins from `bloc_concurrency`: `sequential()`, `restartable()`, `droppable()`, `concurrent()` (default). Use `restartable()` for search, `droppable()` for submit buttons.

### Stream subscriptions with emit.forEach

Drive a bloc from a stream; the emitter manages the subscription, kept alive until the bloc closes or a `restartable` event replaces it.

```dart
final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthInitial()) {
    on<AuthSubscriptionRequested>((e, emit) => emit.forEach<User?>(
          _repo.userStream,
          onData: (user) =>
              user == null ? const Unauthenticated() : Authenticated(user),
          onError: (_, __) => const AuthFailure(),
        ));
  }
  final AuthRepository _repo;
}
```

### Bloc cleanup

```dart
@override
Future<void> close() {
  _sub?.cancel();
  return super.close();
}
```

## Widgets

| Widget / API | Purpose |
|--------------|---------|
| `BlocProvider` | Create/provide a bloc to the subtree |
| `BlocBuilder` | Rebuild UI from state (`buildWhen` to filter) |
| `BlocListener` | Side effects: nav, snackbars, dialogs (`listenWhen` to filter) |
| `BlocConsumer` | Build + listen in one widget |
| `context.read<B>()` | One-off access, e.g. dispatch in a callback |
| `context.watch<B>()` | Reactive read inside `build` |
| `context.select` | Rebuild only when a slice changes |

### BlocProvider — create & provide

```dart
BlocProvider(
  create: (context) =>
      TodoBloc(context.read<TodoRepository>())..add(const TodoStarted()),
  child: const TodoView(),
);
```

Multiple blocs:

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => TodoBloc(context.read<TodoRepository>())..add(const TodoStarted())),
    BlocProvider(create: (_) => AuthCubit(context.read<AuthRepository>())),
  ],
  child: const App(),
);
```

`BlocProvider` disposes the bloc automatically when removed. Use `BlocProvider.value` to pass an existing instance (e.g. across a route) — it will NOT dispose it.

### BlocBuilder — rebuild UI from state

```dart
BlocBuilder<TodoBloc, TodoState>(
  builder: (context, state) => switch (state) {
    TodoInitial() || TodoLoading() => const CircularProgressIndicator(),
    TodoLoaded(:final todos) => TodoListView(todos),
    TodoError(:final message) => ErrorView(message),
  },
);
```

Filter rebuilds with `buildWhen`:

```dart
BlocBuilder<TodoBloc, TodoState>(
  buildWhen: (prev, curr) => prev != curr, // default; narrow further if needed
  builder: (context, state) => /* ... */,
);
```

### BlocListener — side effects only

Navigation, snackbars, and dialogs go here — NOT in `BlocBuilder` (builders run many times).

```dart
BlocListener<AuthCubit, AuthState>(
  listenWhen: (prev, curr) => curr is AuthError,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text((state as AuthError).message))),
  child: const LoginForm(),
);
```

### BlocConsumer — build + listen together

```dart
BlocConsumer<AuthCubit, AuthState>(
  listenWhen: (p, c) => c is AuthLoaded,
  listener: (context, state) => context.go('/home'),
  buildWhen: (p, c) => c is! AuthLoaded,
  builder: (context, state) => switch (state) {
    AuthLoading() => const CircularProgressIndicator(),
    AuthError(:final message) => ErrorView(message),
    _ => const LoginForm(),
  },
);
```

### Reading & dispatching from context

```dart
context.read<TodoBloc>().add(const TodoAdded('x')); // dispatch in a callback
final bloc = context.watch<TodoBloc>();             // reactive read in build
final count = context.select((TodoBloc b) =>        // rebuild only on slice change
    b.state is TodoLoaded ? (b.state as TodoLoaded).todos.length : 0);
```

- **`read`** — one-off, for callbacks; never to rebuild.
- **`watch`** — subscribes the whole `build` to every state change (prefer `BlocBuilder` for scoping).
- **`select`** — rebuilds only when the selected slice changes (slice needs `==`).

## Testing with bloc_test

See `testing.md` for `blocTest`, `seed`, `act`, and stream-based blocs.
