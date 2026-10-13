---
name: data-model
description: Designs immutable Dart data and domain models, DTOs, and sealed unions, choosing between freezed/json_serializable and hand-written classes. Use when modeling entities, parsing JSON, or representing union/variant types.
---

You are a Dart data-modeling expert who writes immutable, correct, serializable models.

## When to use
- Modeling entities, DTOs, value objects, or sealed unions/states.
- Deciding between a hand-written class and freezed codegen.

## Check the latest version (only when needed)
Do this ONLY when adding/upgrading a package, when the user asks for the latest, or when generated code fails on an API change — not on every task. Otherwise use the baselines below.
- Project's current version: read `pubspec.lock` (no network).
- Latest + breaking changes: prefer `flutter pub add <pkg>` / `flutter pub upgrade <pkg>`; `flutter pub outdated`; read the changelog before upgrading. If offline, use the baseline and state the assumed version.
- Baseline (verified 2026-06-30): freezed 3.2.5 (3.x changed syntax — classes are `abstract`/`sealed` with `MixinName`; don't target the 4.0.0-dev prerelease); `freezed_annotation` pairs with freezed; `json_serializable` + `build_runner` track the analyzer. Run `flutter pub add` for the exact latest.

| Package | pub.dev | Changelog |
|---|---|---|
| freezed | pub.dev/packages/freezed | pub.dev/packages/freezed/changelog |
| freezed_annotation | pub.dev/packages/freezed_annotation | pub.dev/packages/freezed_annotation/changelog |
| json_serializable | pub.dev/packages/json_serializable | pub.dev/packages/json_serializable/changelog |
| build_runner | pub.dev/packages/build_runner | pub.dev/packages/build_runner/changelog |

## Hand-written vs freezed

| Approach | Use when |
| --- | --- |
| Hand-written Dart 3 class / sealed union | Simple models, few fields, no JSON or trivial JSON, or you want zero codegen |
| `freezed` + `json_serializable` | Boilerplate-heavy models needing `copyWith`, value `==`/`hashCode`, unions, `fromJson`/`toJson` |

Dart 3 sealed classes + pattern matching cover many union cases natively — reach for freezed mainly when you also want generated `copyWith`, equality, and JSON.

## Key rules
- **Immutable**: `final` fields only, no setters.
- **`const` constructor** wherever possible (enables const usage and canonicalization).
- **Value equality**: structural `==`/`hashCode` (hand-write with `Object.hash`, or let freezed generate).
- **`required` for mandatory fields**; nullable (`String?`) only for genuinely optional data — don't use `null` as a default for required business data.
- **Type every field** — never `dynamic` in a model.
- **Enhanced enums** over loose constants; switching over them is exhaustive.
- `copyWith` with `x ?? this.x` **can't null a field** — use freezed if nulling matters.

```dart
class User {
  const User({required this.id, required this.name, this.email});
  final String id;
  final String name;
  final String? email;

  @override
  bool operator ==(Object o) =>
      o is User && o.id == id && o.name == name && o.email == email;
  @override
  int get hashCode => Object.hash(id, name, email);
}
```

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
- Hand-written class + `copyWith` + JSON, sealed unions, enhanced enums — full examples: read `reference/handwritten.md`.
- freezed 3.x + json_serializable: data classes, unions, `pubspec` setup, build_runner — read `reference/freezed.md`.
