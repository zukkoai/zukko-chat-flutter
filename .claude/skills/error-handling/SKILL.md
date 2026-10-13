---
name: error-handling
description: Builds robust error handling with Result/Either, sealed Failure types, boundary mapping, and global handlers. Use when designing how a Flutter app catches, surfaces, reports, or crash-logs errors.
---

You are a Flutter engineer who designs predictable, exhaustive error handling instead of scattered try/catch (Flutter 3.44 / Dart 3.12).

## When to use
- Designing how repositories/use cases report success vs failure.
- Mapping exceptions to user-facing messages and wiring crash reporting.
- Replacing scattered try/catch with a uniform `Result` flow.

## Core principle
Map exceptions to domain `Failure` objects **at the data-layer boundary**, return a sealed `Result<T>` from repositories/use cases, and handle it **exhaustively** in the UI with pattern matching. Exceptions are not thrown across layers.

## Essential rules
- **Sealed `Result<T>`** = `Success(value)` | `Failure(failure)`; a `fold` extension keeps call sites tidy.
- **Sealed `AppFailure`** hierarchy (Server/Network/Timeout/Unauthorized/Cache/Validation/Unexpected); every failure carries a user-safe `message`.
- **`try/catch` only in data sources** to produce `Failure` — never in the UI.
- **UI switches exhaustively** over `Result` and `AppFailure`; a new category forces a compile-time update.
- **User message vs log** are different audiences — never show raw exceptions/stack traces to users.
- **One global guard** feeds the crash reporter.

## User-facing vs logging
| Audience | Content |
|----------|---------|
| User | Short, friendly, actionable — from `failure.message` |
| Logs / crash reporter | Full exception, stack trace, request context, status code |

## Global handlers (set up once in main)
- `FlutterError.onError` — framework build/layout/paint errors.
- `PlatformDispatcher.instance.onError` — async/platform errors.
- `runZonedGuarded` — uncaught zone errors.
- `ErrorWidget.builder` — friendly screen instead of red box in release.

Wire all of them to one reporter (Crashlytics/Sentry). Never log PII or tokens.

## Common mistakes
- `await` without handling → convert exceptions to a typed `Failure` at the data-layer boundary (see boundary mapping above).
- Empty `catch {}` / silent `catchError((_) {})` → log the error and return a `Failure`; never hide critical errors.
- `print`/logging tokens, passwords, or PII → redact before logging, and strip debug prints in release with `kReleaseMode`.
- Showing raw exceptions/stack traces to users → show `failure.message`; full detail goes to logs only.
- See `reference/anti-patterns.md` for full do/avoid.

## Gotchas
- **Wire BOTH global handlers** — `FlutterError.onError` (framework errors) AND `PlatformDispatcher.instance.onError` (async/platform errors); setting only one leaks crashes (cross-ref `observability`).
- **Never swallow with empty `catch {}`** or silent `catchError((_) {})` — log the error and return a typed `Failure`; hiding it loses the crash report.
- **Don't show raw exceptions/stack traces to users** — surface `failure.message`; full detail goes to logs only.

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
- Sealed `Result<T>` + `fold` extension: read `reference/result-type.md`.
- Full `AppFailure` hierarchy: read `reference/failures.md`.
- Boundary mapping + exhaustive UI handling + user messages: read `reference/boundary-mapping.md`.
- Global handlers + crash-reporting hook (Crashlytics/Sentry): read `reference/global-handlers.md`.
- Common mistakes with full do/avoid (unhandled async, swallowed errors, logging secrets): read `reference/anti-patterns.md`.
