# Testing — Riverpod (ProviderContainer) + Bloc (bloc_test)

---

# Riverpod

## ProviderContainer + overrides (unit tests)

Build a `ProviderContainer`, override dependencies with fakes, and always `addTearDown(container.dispose)`. In Riverpod 3 prefer the `ProviderContainer.test()` helper — it auto-disposes at the end of the test, so you can skip the manual `addTearDown`. (Full testing patterns live in `flutter-test`; this is just the state-management slice.)

```dart
test('loads todos', () async {
  final container = ProviderContainer(
    overrides: [
      todoRepositoryProvider.overrideWithValue(FakeTodoRepo()),
    ],
  );
  addTearDown(container.dispose);

  // initial state is loading
  expect(container.read(todoListProvider), const AsyncLoading<List<Todo>>());

  // await the load
  await container.read(todoListProvider.future);
  expect(container.read(todoListProvider).value, hasLength(2));
});
```

## Overriding a Notifier/AsyncNotifier

```dart
ProviderContainer(
  overrides: [
    todoListProvider.overrideWith(() => FakeTodoList()), // returns a notifier instance
  ],
);
```

## Listening to emitted states

`container.listen` captures successive values — useful for asserting a sequence after an action.

```dart
test('add appends a todo', () async {
  final container = ProviderContainer(
    overrides: [todoRepositoryProvider.overrideWithValue(FakeTodoRepo())],
  );
  addTearDown(container.dispose);
  await container.read(todoListProvider.future);

  await container.read(todoListProvider.notifier).add('new');

  expect(container.read(todoListProvider).value, contains(predicate<Todo>((t) => t.title == 'new')));
});
```

## Widget tests — wrap in ProviderScope

```dart
testWidgets('shows todos', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [todoRepositoryProvider.overrideWithValue(FakeTodoRepo())],
      child: const MaterialApp(home: TodosPage()),
    ),
  );
  await tester.pumpAndSettle(); // let the future resolve
  expect(find.byType(TodoView), findsOneWidget);
});
```

## Tips
- Override at the **lowest** level you can (the repository), so the real provider logic still runs.
- `overrideWithValue` for a constant; `overrideWith` to supply a builder/notifier.
- For `keepAlive` providers, disposing the container still cleans them up in tests.

---

# Bloc — bloc_test

`blocTest` builds a bloc, optionally seeds state, runs `act`, and asserts the emitted state sequence.

## Basic sequence

```dart
blocTest<TodoBloc, TodoState>(
  'emits [Loading, Loaded] on TodoStarted',
  build: () => TodoBloc(fakeRepo),
  act: (bloc) => bloc.add(const TodoStarted()),
  expect: () => [const TodoLoading(), TodoLoaded(fixtureTodos)],
  verify: (_) => verify(() => fakeRepo.fetchAll()).called(1),
);
```

`expect` compares with `==`, so state classes need value equality (Equatable). This is also why a dropped-emit (new state equal to old) shows up as a missing entry.

## Seeding a starting state

```dart
blocTest<TodoBloc, TodoState>(
  'removes a todo from a loaded list',
  build: () => TodoBloc(fakeRepo),
  seed: () => TodoLoaded(fixtureTodos),          // start already loaded
  act: (bloc) => bloc.add(TodoDeleted('1')),
  expect: () => [TodoLoaded(fixtureTodos.where((t) => t.id != '1').toList())],
);
```

## Async setup and timing

```dart
blocTest<AuthCubit, AuthState>(
  'emits [Loading, Loaded] on successful login',
  setUp: () => when(() => fakeRepo.login(any(), any()))
      .thenAnswer((_) async => Success(fixtureUser)),
  build: () => AuthCubit(fakeRepo),
  act: (cubit) => cubit.login('a@b.com', 'pw'),
  wait: const Duration(milliseconds: 300), // for debounced/delayed emits
  expect: () => [const AuthLoading(), AuthLoaded(fixtureUser)],
);
```

## Stream-based blocs

```dart
blocTest<AuthBloc, AuthState>(
  'maps user stream to auth states',
  build: () {
    when(() => fakeRepo.userStream)
        .thenAnswer((_) => Stream.value(fixtureUser));
    return AuthBloc(fakeRepo);
  },
  act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
  expect: () => [Authenticated(fixtureUser)],
);
```

## Tips
- Use `errors: () => [isA<MyException>()]` to assert thrown errors.
- Use `skip:` to ignore the first N states.
- Register fallback values for sealed/custom types with `registerFallbackValue` before `any()` matchers (mocktail).
