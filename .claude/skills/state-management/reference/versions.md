# Versions & freshness protocol

State-management packages move fast. This file is the source of truth for **what version a project is on**, **how to find the latest**, and **when to bother checking**.

## When to check (and when NOT to)

Check the latest version ONLY when:
- adding a package, or upgrading one,
- the user explicitly asks for the latest, or
- generated/written code fails because of an API change (a method moved/renamed).

**Otherwise use the baseline below.** Do not run a version check on every task — it wastes time and the baseline is fine for normal work.

## The project's current version — read pubspec.lock (no network)

`pubspec.lock` pins the exact resolved version of every dependency. Find the package and read the `version:` line under it:

```yaml
packages:
  flutter_riverpod:
    dependency: "direct main"
    source: hosted
    version: "3.3.2"     # <- this is what the project actually runs
```

Use this for "what is this project on". `pubspec.yaml` only shows the constraint (e.g. `^3.3.1`), not the resolved version — prefer `pubspec.lock` for the real answer.

## The latest available version + breaking changes

Prefer the tooling (reliable, resolves compatibility for you):

- `flutter pub add <pkg>` — adds the newest version compatible with the current SDK/constraints.
- `flutter pub upgrade <pkg>` — upgrades an existing dependency to the newest compatible.
- `flutter pub outdated` — lists which packages have newer versions available.

Web (when tooling isn't available or you want to read changes first):

- `https://pub.dev/packages/<pkg>` — latest version + readme.
- `https://pub.dev/packages/<pkg>/changelog` — **breaking changes between versions; read this before upgrading.**
- `https://pub.dev/api/packages/<pkg>` — JSON; `latest.version` is first. Note: large response — prefer the changelog page.

**If offline / no web access:** use the baseline below and state the assumed version explicitly in your answer.

## Package → URL table

| Package | Role | Latest | Changelog |
|---|---|---|---|
| flutter_riverpod | Riverpod core (Flutter) | pub.dev/packages/flutter_riverpod | pub.dev/packages/flutter_riverpod/changelog |
| riverpod_annotation | `@riverpod` annotations | pub.dev/packages/riverpod_annotation | pub.dev/packages/riverpod_annotation/changelog |
| riverpod_generator | Codegen for `@riverpod` | pub.dev/packages/riverpod_generator | pub.dev/packages/riverpod_generator/changelog |
| flutter_bloc | Bloc/Cubit + widgets | pub.dev/packages/flutter_bloc | pub.dev/packages/flutter_bloc/changelog |
| bloc | Bloc core (Dart) | pub.dev/packages/bloc | pub.dev/packages/bloc/changelog |
| bloc_test | Testing blocs/cubits | pub.dev/packages/bloc_test | pub.dev/packages/bloc_test/changelog |
| hydrated_bloc | Persisted bloc state | pub.dev/packages/hydrated_bloc | pub.dev/packages/hydrated_bloc/changelog |
| provider | InheritedWidget DI | pub.dev/packages/provider | pub.dev/packages/provider/changelog |
| get_it | Service locator / DI | pub.dev/packages/get_it | pub.dev/packages/get_it/changelog |

## Baseline versions (verified 2026-06-30)

| Package | Version | Notes |
|---|---|---|
| flutter_riverpod | 3.3.2 | Riverpod 3: codegen `@riverpod`, `Notifier`/`AsyncNotifier`. Legacy `StateProvider`/`StateNotifierProvider`/`ChangeNotifierProvider` moved to `package:flutter_riverpod/legacy.dart` — avoid. |
| riverpod_annotation | 4.0.3 | Version line **differs** from `flutter_riverpod` (3.3.2) — don't "align" them. Pair with `riverpod_generator` + `build_runner`. |
| flutter_bloc | 9.1.1 | Cubit + Bloc. Pair with `bloc_test`, `equatable` (or freezed) for states. |
| bloc_test | 10.0.0 | Testing blocs/cubits. |
| provider | 6.1.5+1 | Lightweight DI / `ChangeNotifier`. |
| get_it | 9.2.1 | Service locator / DI. |

Always prefer `flutter pub add <pkg>` to pull the latest compatible version rather than hardcoding these numbers — the baseline exists so you have an answer when you can't run tooling or reach the web.
