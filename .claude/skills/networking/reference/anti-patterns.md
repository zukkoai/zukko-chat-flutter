# Common mistakes & anti-patterns (networking)

The layering (one configured Dio, interceptors, retrofit client, mapper,
repository) is covered in `SKILL.md` and the other reference files. This file
covers the recurring security/config traps.

## 15. Hardcoded base URLs / API keys

Literal base URLs and API keys baked into the client can't switch between
dev/staging/prod, and committed secrets end up in version control forever. Inject
configuration from an `Env`/config object built from `--dart-define`; never commit
real secrets.

```dart
// AVOID — environment + secret baked into source, committed to the repo
final dio = Dio(BaseOptions(baseUrl: 'https://api.prod.example.com'));
dio.options.headers['X-Api-Key'] = 'sk_live_9f3a...';   // secret in git history
```

```dart
// DO — read from --dart-define via a typed Env, inject the configured Dio
class Env {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.dev.example.com', // safe non-secret dev default
  );
  static const apiKey = String.fromEnvironment('API_KEY'); // no default for secrets
}

Dio buildDio() => Dio(BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'X-Api-Key': Env.apiKey},
    ));
```

```bash
# pass per environment at build/run time — secrets stay out of source
flutter run --dart-define=API_BASE_URL=https://api.prod.example.com \
            --dart-define=API_KEY=$API_KEY
```

Use `--dart-define-from-file=env.json` for many values, and add that file to
`.gitignore`. For high-value secrets, prefer a backend proxy so the key never
ships in the app binary at all.

## 22. Logging sensitive data

`LogInterceptor` (or any logging interceptor) with headers/bodies enabled dumps
`Authorization` tokens, cookies, passwords, and PII into device logs — and in a
release build those logs can be collected off-device. Enable logging only in
debug, and redact `Authorization` even there.

```dart
// AVOID — full headers + bodies logged, including in release builds
dio.interceptors.add(LogInterceptor(
  requestHeader: true,   // logs Authorization: Bearer <token>
  requestBody: true,     // logs passwords in login bodies
  responseBody: true,    // logs PII in responses
));
```

```dart
// DO — debug-only, with sensitive headers redacted
import 'package:flutter/foundation.dart';

class RedactingLogInterceptor extends Interceptor {
  static const _sensitive = {'authorization', 'cookie', 'x-api-key'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final headers = {
        for (final e in options.headers.entries)
          e.key: _sensitive.contains(e.key.toLowerCase()) ? '***' : e.value,
      };
      debugPrint('--> ${options.method} ${options.uri}  headers=$headers');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('<-- ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }
}

// wire it only in debug
if (kDebugMode) dio.interceptors.add(RedactingLogInterceptor());
```

Never log full request/response bodies that may carry credentials or PII. If you
need body logging while debugging, redact known sensitive fields first, and keep
the interceptor behind `kDebugMode` so it can never run in release.
