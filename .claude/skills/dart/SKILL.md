---
name: dart
description: Writes or reviews idiomatic Dart 3 code — null safety, var/final/const/late/required, naming, single responsibility, pattern matching, sealed classes. Use when authoring, refactoring, or reviewing any .dart file.
---

You are a Dart 3.12 expert who writes idiomatic, null-safe, clean code following Effective Dart.

## When to use
- Authoring or reviewing any Dart source file.
- Naming things, choosing `var`/`final`/`const`/`late`, or shaping classes and functions.

## Route to specialist Dart skills (invoke via the Skill tool)
Before coding, pull in the matching skill when the task goes beyond plain language rules:

| Task touches | Invoke |
|---|---|
| Data/domain models, DTOs, unions, JSON, freezed | `data-model` |
| Futures, streams, isolates, concurrency | `async` |
| Lints / `analysis_options.yaml` | `dart-analyze` |
| Unit tests, mocktail | `dart-test` |
| Allocation/typing performance | `dart-optimization` |

In a Flutter app, start from the `flutter` skill — it orchestrates these plus the Flutter specialists.

## Detect first
Match the project: read `pubspec.yaml` (SDK + codegen packages), follow the existing `analysis_options.yaml` lints and file/folder naming. Don't impose a different style.

## Naming (Effective Dart)

| Element | Convention | Example |
| --- | --- | --- |
| Types, enums, extensions, typedefs | `UpperCamelCase` | `class HttpClient`, `enum LogLevel` |
| Members, vars, params, functions | `lowerCamelCase` | `final userId`, `void fetchData()` |
| Constants | `lowerCamelCase` (not `SCREAMING_CAPS`) | `const maxRetries = 3` |
| Files, directories | `snake_case` | `user_repository.dart` |
| Type parameters | single cap or `UpperCamelCase` | `Map<K, V>` |

- **Intention-revealing names**: `remainingRetries`, not `n` or `temp`.
- **No abbreviations**: `database`, not `db`; acronyms >2 letters are words — `HttpClient`, `userId` (not `HTTPClient`).
- **Booleans read as predicates**: `isEmpty`, `hasError`, `canRetry` — not `flag`, `status`.

## Declaration rules

| Need | Use |
| --- | --- |
| Never reassigned (default choice) | `final` |
| Local that is reassigned | `var` |
| Compile-time constant value | `const` |
| Deferred init needing `this`/other fields | `late final` |
| Mandatory named param | `required` |

- Default to **`final`**; reach for `var` **only** when you actually reassign.
- `const` for compile-time constants and constructors — avoid `final` where `const` is legal.
- `late final` for init that can't run in the initializer list; **avoid bare `late`** without a real need (reading before assignment throws).
- Flutter-style named params: mark mandatory ones `required`, make truly-optional ones nullable.

## Single Responsibility & function extraction
- **One class = one reason to change**; **one method = one job**. Split a class that mixes parsing + I/O + formatting.
- Keep functions small and focused; a method doing three things is three methods.
- **Extract repeated logic into a named function** — don't copy-paste a block; pull shared logic into a well-named method and call it.

## Critical pitfalls
- Force-unwrap `!`: reserve for proven non-null; prefer `?.`, `??`, `??=`.
- Raw generics: write `List<String>`, never bare `List`; avoid `dynamic` fields.
- `copyWith` with `x ?? this.x` **cannot set a field back to null** — use freezed/sentinel if nulling matters.

```dart
sealed class Result<T> { const Result(); }
final class Ok<T> extends Result<T> { const Ok(this.value); final T value; }
final class Err<T> extends Result<T> { const Err(this.message); final String message; }

String render(Result<int> r) => switch (r) {
  Ok(:final value) => 'ok: $value',
  Err(:final message) => 'err: $message',
};
```

## Common mistakes
- Magic numbers/strings: `if (role == 'admin')` → name a `const` or `enum` (`Role.admin`).
- Dead code: unused vars/methods/imports → delete them; the analyzer flags them.
- Spaghetti: long function with deep if-else/callback nesting → small functions, early returns, `switch` expressions.
- `late` that may never be set → `late final` set in constructor/`initState`, or make it nullable.
- `dynamic`/raw generics to dodge typing → precise types, bounded generics `<T extends X>`.
- Skipping fundamentals: master null safety, async/await, futures/streams before reaching for heavy abstractions.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (compiles, analyzer clean, tests pass).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Full naming + style examples (null-aware, expression bodies, extensions, doc comments, collection literals): read `reference/naming-and-style.md`.
- `var`/`final`/`const`/`late`/`required` worked examples incl. pitfalls (copyWith-can't-null): read `reference/declarations.md`.
- Sealed classes, pattern matching, records, class modifiers — full examples: read `reference/patterns.md`.
- Extension methods (static dispatch footgun), mixins (linearization order), callable classes, custom operators: read `reference/extensions-and-mixins.md`.
- Collections & iterables (laziness re-evaluation), generics & variance (`covariant`, bounded type params): read `reference/collections-and-generics.md`.
- Anti-patterns with do/avoid examples (bang, copy-paste, magic values, dead code, god class, `late`, `dynamic`, spaghetti): read `reference/anti-patterns.md`.
