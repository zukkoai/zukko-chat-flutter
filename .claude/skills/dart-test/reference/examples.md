# Full example test file & coverage

## Complete test file

```dart
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myapp/user/get_user_use_case.dart';

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockUserRepository repo;
  late GetUserUseCase useCase;

  setUpAll(() {
    registerFallbackValue(const User(id: '', name: ''));
  });

  setUp(() {
    repo = MockUserRepository();
    useCase = GetUserUseCase(repo);
  });

  group('GetUserUseCase', () {
    const id = 'user-123';
    const user = User(id: id, name: 'Alice');

    test('should return user when repository succeeds', () async {
      // Arrange
      when(() => repo.getUser(id)).thenAnswer((_) async => user);

      // Act
      final result = await useCase.execute(id);

      // Assert
      expect(result, equals(user));
      verify(() => repo.getUser(id)).called(1);
    });

    test('should throw NotFoundException when user is missing', () async {
      // Arrange
      when(() => repo.getUser(any()))
          .thenThrow(const NotFoundException('missing'));

      // Act & Assert
      await expectLater(
        () => useCase.execute('unknown'),
        throwsA(isA<NotFoundException>()),
      );
    });

    // Parameterized: one behavior, many inputs
    for (final raw in ['', '   ', '\n']) {
      test('should reject blank id "${raw.trim()}"', () {
        expect(() => useCase.execute(raw), throwsArgumentError);
      });
    }
  });
}
```

## Matchers

Use intent-revealing matchers over raw equality: `isNull`, `isEmpty`, `contains`, `isA<T>()`, `closeTo`, `throwsA`, `completion`, `emitsInOrder`. Compose with `allOf`/`anyOf`.

## Coverage

```bash
dart test --coverage=coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

Chase meaningful branch coverage (error paths, edge cases), not a vanity percentage.
