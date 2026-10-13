# Common mistakes & anti-patterns (error handling)

The sealed `Result<T>`/`AppFailure` design and boundary mapping are covered in
`SKILL.md`, `reference/result-type.md`, `reference/failures.md`, and
`reference/boundary-mapping.md`. This file covers the recurring traps.

## 6. Unhandled async errors

Awaiting a call without handling its failure lets an exception escape the data
layer and surface as an unhandled async error (or a red screen) somewhere far from
the cause. Convert exceptions to a typed `Failure` **at the boundary** and return
a `Result<T>`; never `await` raw exceptions across layers.

```dart
// AVOID — exception escapes the data layer; caller has no typed signal
Future<User> fetchUser(String id) async {
  final response = await dio.get('/users/$id'); // throws DioException on failure
  return User.fromJson(response.data);          // throws on bad JSON too
}
```

```dart
// DO — catch at the boundary, map to a typed Failure, return a Result
Future<Result<User>> fetchUser(String id) async {
  try {
    final response = await _dio.get('/users/$id');
    return Success(User.fromJson(response.data));
  } on DioException catch (e, st) {
    _logger.error('fetchUser failed', error: e, stackTrace: st);
    return Failure(mapDioException(e));         // ServerFailure / NetworkFailure / ...
  } on FormatException catch (e, st) {
    _logger.error('fetchUser parse failed', error: e, stackTrace: st);
    return const Failure(UnexpectedFailure('Could not read the server response.'));
  }
}
```

Full boundary-mapping patterns: `reference/boundary-mapping.md`.

## 21. Swallowing errors

An empty `catch {}` or a silent `catchError((_) {})` hides the failure: the user
sees nothing change, no `Failure` propagates, and crash reporting never fires.
Always log the error **and** return a `Failure` — never hide critical errors.

```dart
// AVOID — swallowed; the app silently does nothing, bug is invisible
try {
  await _repo.save(order);
} catch (_) {}                    // no log, no Failure, no user feedback

future.catchError((_) {});        // same problem with Futures
```

```dart
// DO — log with context, then surface a typed Failure
Future<Result<void>> save(Order order) async {
  try {
    await _dataSource.save(order);
    return const Success(null);
  } catch (e, st) {
    _logger.error('save order failed', error: e, stackTrace: st); // for engineers
    return const Failure(UnexpectedFailure('Could not save your order.')); // for the user
  }
}
```

If a particular error truly is ignorable, catch the **specific** type and add a
comment saying why — don't blanket-swallow everything.

```dart
// Deliberate, narrow, documented — acceptable
try {
  await _analytics.track(event);
} on AnalyticsException catch (e) {
  _logger.warn('analytics dropped (non-critical)', error: e); // never block UX on analytics
}
```

## 22. Logging secrets / PII

`print` or logging tokens, passwords, full request bodies, or PII leaks them into
device logs, log aggregators, and crash reports. Redact sensitive fields before
logging, and strip debug prints from release builds with `kReleaseMode`.

```dart
// AVOID — secrets and PII end up in logs / crash reports
print('login body: ${jsonEncode(body)}');          // contains the password
log('Authorization: ${response.requestOptions.headers['Authorization']}'); // the token
_logger.info('user: ${user.toJson()}');             // email, phone, address
```

```dart
// DO — redact, and gate debug prints behind kReleaseMode
String redact(Map<String, dynamic> data) {
  const sensitive = {'password', 'token', 'authorization', 'email', 'ssn'};
  return jsonEncode({
    for (final e in data.entries)
      e.key: sensitive.contains(e.key.toLowerCase()) ? '***' : e.value,
  });
}

void debugLog(String message) {
  if (kReleaseMode) return;        // never runs in release
  debugPrint(message);             // also auto-stripped, but be explicit
}

// usage
debugLog('login body: ${redact(body)}');                 // password -> ***
_logger.info('login for userId=${user.id}');             // stable id, not PII
```

Configure your crash reporter the same way — scrub `Authorization` headers and PII
before an event is sent. The rule: logs are for engineers, but logs are not
private — treat every log line as potentially shipped off-device.
