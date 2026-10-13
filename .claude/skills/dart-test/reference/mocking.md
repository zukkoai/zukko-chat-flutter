# Mocking with mocktail

mocktail needs no build step — that's why it's **preferred over `mockito`** (5.7.0), which requires `build_runner` codegen via `@GenerateMocks`. Subclass `Mock` and implement the contract.

```dart
class MockUserRepository extends Mock implements UserRepository {}
```

## Stubbing — when

```dart
// Sync return
when(() => repo.cachedName()).thenReturn('Alice');

// Async return
when(() => repo.getUser('id')).thenAnswer((_) async => user);

// Throw
when(() => repo.getUser(any())).thenThrow(const NotFoundException('missing'));

// Use the captured argument in the answer
when(() => repo.getUser(any()))
    .thenAnswer((inv) async => User(id: inv.positionalArguments.first as String, name: 'X'));
```

## Verifying — verify

```dart
verify(() => repo.getUser('id')).called(1);   // exactly once
verifyNever(() => repo.delete(any()));         // never called
verifyInOrder([                                // ordering matters
  () => repo.open(),
  () => repo.read(),
  () => repo.close(),
]);
```

Don't over-verify — assert on observable outcomes, not every internal call.

## any() and registerFallbackValue

`any()` matches any argument. For **non-primitive** types, mocktail needs a fallback instance registered once (typically in `setUpAll`), or `any()` throws.

```dart
setUpAll(() {
  registerFallbackValue(const User(id: '', name: ''));
  registerFallbackValue(Uri());
});

when(() => repo.save(any())).thenAnswer((_) async {});
verify(() => repo.save(any())).called(1);
```

Primitives (`int`, `String`, `bool`, etc.) don't need a fallback.

## Fakes vs mocks

| Use | When |
| --- | --- |
| Mock (mocktail) | Verify interactions (`verify`, `.called(n)`) or stub return values per test |
| Fake | A lightweight working implementation (e.g. in-memory repo) reused across many tests |

A fake holds real behavior; a mock records and stubs calls.
