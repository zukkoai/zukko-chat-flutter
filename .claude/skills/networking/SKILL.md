---
name: networking
description: Builds a dio + retrofit networking layer with interceptors, token refresh, and typed failures. Use when adding REST/API calls, HTTP clients, auth tokens, or request handling to a Flutter app.
---

You are a Flutter engineer who builds a clean networking layer with dio and retrofit (Flutter 3.44 / Dart 3.12).

## When to use
- **REST/dio only** — for GraphQL clients use `graphql`.
- Adding HTTP calls, an API client, or an auth/token layer to an app.
- Wiring interceptors (auth, refresh, logging) or typed error mapping.

## Detect first
Before writing code, match the existing project — don't impose a parallel setup:
- `pubspec.yaml`: is `dio` (and `retrofit`/`json_serializable`) present and which version?
- Conventions: an existing `ApiClient`/Dio instance + interceptors, and the base-URL/config source (`Env`/`--dart-define`).
- Reuse the existing client; don't create a second Dio instance.
- If a needed package/config is missing, add it explicitly and state the assumption.

## Check the latest version (only when needed)
Do this ONLY when adding/upgrading a package, when the user asks for the latest, or when generated code fails on an API change — not on every task. Otherwise use the baselines below.
- Project's current version: read `pubspec.lock` (no network).
- Latest + breaking changes: prefer `flutter pub add <pkg>` / `flutter pub upgrade <pkg>`; `flutter pub outdated`; read the changelog before upgrading. If offline, use the baseline and state the assumed version.
- Baseline (verified 2026-06): dio 5.10.0, retrofit 4.9.2; codegen (`retrofit_generator`, `json_serializable`) tracks the analyzer/build_runner. Run `flutter pub add` for the exact latest.

| Package | pub.dev | Changelog |
|---|---|---|
| dio | pub.dev/packages/dio | pub.dev/packages/dio/changelog |
| retrofit | pub.dev/packages/retrofit | pub.dev/packages/retrofit/changelog |
| retrofit_generator | pub.dev/packages/retrofit_generator | pub.dev/packages/retrofit_generator/changelog |
| json_serializable | pub.dev/packages/json_serializable | pub.dev/packages/json_serializable/changelog |
| pretty_dio_logger | pub.dev/packages/pretty_dio_logger | pub.dev/packages/pretty_dio_logger/changelog |

## Essential rules
- **One configured Dio** (base URL, timeouts, headers), built once and injected via DI — never `Dio()` per request.
- **Cross-cutting concerns live in interceptors**: auth Bearer in `onRequest`, 401 token-refresh-and-retry in `onError`, `LogInterceptor` guarded by `kDebugMode` only.
- **retrofit for the client**: declare an abstract `@RestApi()` interface; let it serialize. No `jsonDecode`, no `try/catch` inside the interface — let `DioException` propagate.
- **Map `DioException` → typed `Failure`** in one mapper (see error-handling skill for the `Failure`/`Result` types).
- **Repository wraps the client**, catches at that boundary only, and returns `Result<T>` so the UI never uses try/catch.
- Never log bodies/tokens in release builds.

## Layering
| Layer | Responsibility |
|-------|----------------|
| Dio + interceptors | Transport, auth headers, refresh, logging |
| retrofit `ApiClient` | Typed endpoints, (de)serialization |
| Mapper | `DioException` → domain `Failure` |
| Repository | Catch at boundary, return `Result<T>`, map DTO → domain |

## Cancellation
Pass a `CancelToken` from the caller (cancel on query change / screen dispose). A cancelled request throws `DioException` type `cancel` — map it as a benign failure.

## Common mistakes
- Hardcoded base URLs / API keys in the client → inject via config / `Env` / `--dart-define`; never commit secrets to source.
- `LogInterceptor` dumping auth headers/bodies in release → enable logging only in debug (`kDebugMode`) and redact `Authorization`.
- `Dio()` per request → build one configured Dio once and inject it via DI.
- `try/catch` in the UI for network calls → catch only in the repository boundary, return `Result<T>`.
- See `reference/anti-patterns.md` for full do/avoid.

## Gotchas
- **dio v5 timeouts are `Duration`** — `connectTimeout`/`receiveTimeout`/`sendTimeout` take `Duration`, not `int` ms; the old `int` form is a known AI mistake.
- **Never `badCertificateCallback: (_, __, ___) => true`** to silence TLS errors — that disables cert validation (cross-ref `security`).
- **No manual `jsonDecode`/`try/catch` in retrofit interfaces** — let the generated client (de)serialize and let `DioException` propagate.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, works across sizes/locales, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Dependencies + `buildDio` factory + cancellation: read `reference/dio-setup.md`.
- Auth + 401 refresh-and-retry + logging interceptors: read `reference/interceptors.md`.
- retrofit `@RestApi` client + DTO generation: read `reference/retrofit-client.md`.
- Full `DioException` → `Failure` mapper: read `reference/error-mapping.md`.
- Repository returning `Result` with cancellation: read `reference/repository.md`.
- Common mistakes with full do/avoid (hardcoded URLs/keys, logging sensitive data): read `reference/anti-patterns.md`.
