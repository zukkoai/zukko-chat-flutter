# Async & stream testing

## Always await

Always `await` async calls and `expectLater`. A forgotten `await` makes a failing future pass silently (false positive).

```dart
// Avoid: not awaited — a thrown error escapes the test and may not fail it
expectLater(repo.load(), completion(isNotNull));

// Prefer
await expectLater(repo.load(), completion(isNotNull));
```

## Future matchers

```dart
// Completes with a value matching a matcher
await expectLater(repo.load(), completion(isNotNull));
await expectLater(repo.count(), completion(equals(3)));

// Completes with an error
await expectLater(repo.load(), throwsA(isA<TimeoutException>()));

// A throwing call (wrap in a closure)
await expectLater(() => useCase.execute('bad'), throwsArgumentError);
```

## Stream matchers

```dart
// Emissions in order, then done
expect(counter.stream, emitsInOrder([1, 2, 3, emitsDone]));

// Emits an error
expect(source.stream, emitsError(isA<StateError>()));

// Partial / combined expectations
expect(source.stream, emitsInOrder([1, emitsAnyOf([2, 3]), emitsDone]));
```

## Controlling time

For timers/delays, use `package:fake_async` (or Flutter's `tester.pump(duration)`) so tests stay fast and deterministic instead of real `Future.delayed` waits.

```dart
import 'package:fake_async/fake_async.dart';

test('debounce fires once after the window', () {
  fakeAsync((async) {
    final calls = <String>[];
    final d = Debouncer(const Duration(milliseconds: 300));
    d.run(() => calls.add('a'));
    d.run(() => calls.add('b'));
    async.elapse(const Duration(milliseconds: 300));
    expect(calls, ['b']);
  });
});
```
