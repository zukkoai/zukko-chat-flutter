# Unit and widget tests

## Unit tests with mocktail

`mocktail` needs no codegen — **prefer it over `mockito`** (5.7.0), which requires `build_runner` + `@GenerateMocks`. Mock the dependency, stub it, exercise the unit, verify.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late SignIn signIn;

  setUp(() {
    repo = MockAuthRepository();
    signIn = SignIn(repo);
  });

  test('returns user on valid credentials', () async {
    const user = User(id: '1', email: 'a@b.com', name: 'A');
    when(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const Success(user));

    final result = await signIn(email: 'a@b.com', password: 'pw');

    expect(result, const Success(user));
    verify(() => repo.signIn(email: 'a@b.com', password: 'pw')).called(1);
  });

  test('short-circuits on invalid email without hitting repo', () async {
    final result = await signIn(email: 'bad', password: 'pw');
    expect(result, isA<Failure>());
    verifyNever(() => repo.signIn(email: any(named: 'email'), password: any(named: 'password')));
  });
}
```

Register fallback values for custom argument types with `registerFallbackValue(...)` in `setUpAll`.

## Widget tests

Pump the widget, find elements, drive interactions, assert.

```dart
testWidgets('tapping submit shows loading then result', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: SignInForm()));

  expect(find.byType(CircularProgressIndicator), findsNothing);

  await tester.enterText(find.byKey(const Key('email')), 'a@b.com');
  await tester.tap(find.byKey(const Key('submit')));
  await tester.pump();                       // start async work
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  await tester.pumpAndSettle();              // let futures + animations finish
  expect(find.text('Welcome'), findsOneWidget);
});
```

## Finders and matchers

| Finder | Matcher |
|--------|---------|
| `find.text('x')`, `find.byKey(...)`, `find.byType(T)`, `find.byIcon(...)` | `findsOneWidget`, `findsNothing`, `findsNWidgets(n)`, `findsWidgets` |

## pump vs pumpAndSettle

- `pump()` advances a single frame — use it to step through async/animation states deliberately.
- `pumpAndSettle()` pumps until no more frames are scheduled (animations done).
- **Never `pumpAndSettle()` with an infinite animation** (e.g. a perpetual spinner) — it times out. Use `pump(duration)` to advance a fixed amount instead.
- Use stable `Key`s on interactive widgets so finders don't depend on text/labels that may change or be localized.
