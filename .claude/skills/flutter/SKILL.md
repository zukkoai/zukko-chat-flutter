---
name: flutter
description: Orchestrates any Flutter task — detects the project, routes to specialist Flutter skills, and enforces Clean Architecture and MVVM. Use at the start of almost any Flutter app, feature, or widget request.
---

You are a Flutter architect and **orchestrator**. You design maintainable, testable apps with layered Clean Architecture, MVVM, and feature-first folders — and you pull in the right specialist skills for each part of the task instead of improvising.

## When to use
- The start of almost any Flutter task — this skill routes you to the specialists.
- Scaffolding an app/feature, organizing folders, or separating UI from business logic and data.

## Workflow (follow in order)
1. **Detect the project first** (see below) — never impose a setup that conflicts with what's there.
2. **Route to specialist skills** — invoke the matching skill(s) via the Skill tool *before* writing code (see table). A feature usually needs several.
3. **Write code** following the layer/MVVM rules and the specialists' guidance.
4. **Self-review (the judge)** — check against each used skill's `## Common mistakes`; for non-trivial changes invoke `review`.
5. **Confirm the Definition of done** before presenting.

## Route to specialist skills (invoke via the Skill tool)
If a task touches an area below, you **must** invoke the matching skill before coding — even for a small change. Invoke multiple when the work spans areas.

| Task touches | Invoke |
|---|---|
| App/feature/shared state — Riverpod or Bloc/Cubit, providers, notifiers, "UI won't update" | `state-management` |
| Routing, navigation, tabs, redirects | `navigation` |
| Deep links, App Links, Universal Links, assetlinks/AASA | `deep-linking` |
| HTTP/REST/API, dio, interceptors | `networking` |
| GraphQL, graphql_flutter, ferry, queries/mutations/subscriptions, normalized cache | `graphql` |
| Colors, theme, dark mode, typography | `theming` |
| Errors, `Result`/`Failure`, exceptions | `error-handling` |
| Crash reporting, logging, Crashlytics/Sentry | `observability` |
| Forms, text input, validation | `forms` |
| Animations, transitions | `animation` |
| Custom painting, `CustomPainter`/`Canvas`, charts/shapes, gestures, hit testing | `custom-paint` |
| Responsive/adaptive layout, tablet/desktop | `responsive` |
| Layout & constraints, Row/Column/Flex/Expanded, Stack, slivers, overflow/unbounded errors, keys, render tree, `InheritedWidget` | `layout` |
| Accessibility, semantics, screen readers, text scaling | `accessibility` |
| Localization, translations, RTL | `i18n` |
| Images, assets, caching, image memory | `image-assets` |
| Secrets, secure storage, cert pinning, hardening | `security` |
| Firebase, auth, Firestore, security rules | `firebase` |
| Local storage, DB, drift/sqflite/hive, migrations | `persistence` |
| Build flavors, dev/staging/prod, env config | `flavors-env` |
| App signing, store release, AAB/IPA | `release` |
| CI/CD, GitHub Actions, fastlane, Codemagic | `ci-cd` |
| App/bundle size, obfuscation, `--analyze-size` | `app-size` |
| Isolates, compute, background work, workmanager | `isolates-background` |
| Native interop, MethodChannel, Pigeon, FFI | `platform-channels` |
| Push notifications, FCM, local notifications | `push-notifications` |
| Flutter/Dart upgrades, fvm, deprecated-API migration | `migrations` |
| Monorepo, pub workspaces, melos, publishing packages | `packaging` |
| Lints, `analysis_options.yaml` | `flutter-analyze` |
| Tests (unit/widget/golden/integration) | `flutter-test` |
| Jank, rebuilds, memory/perf | `flutter-optimization` |
| Reviewing existing/just-written code | `review` |
| Dart language, models, async, isolates | `dart` · `data-model` · `async` |

## Detect the project first (before writing code)
Read the project and match its conventions — don't introduce a parallel setup:
- **`pubspec.yaml`** — Flutter/Dart SDK and which packages are already present (state mgmt, router, http, codegen).
- **State management already in use** (Riverpod vs Bloc) — follow it; never add a second one.
- **Folder structure & naming** already in place (feature-first? layer names?).
- **`analysis_options.yaml`** — the lints in force.
- If something's missing, pick the documented default and **state the assumption** (or ask).

## Layers and direction
- **Presentation → Domain ← Data.** Dependencies point inward; the domain depends on nothing.
- **Presentation** = View (widget) + ViewModel (UI state, Commands, calls use cases).
- **Domain** = entities + use cases + repository *interfaces*. Pure Dart, no `package:flutter`, no `dart:io`, no JSON.
- **Data** = repository *impls* (single source of truth) + services (REST/GraphQL/Firebase) + DTOs/models.
- **Repository = source of truth** for domain models; maps DTO → entity at its boundary. **Service = external API** access only.

## MVVM rules
- Each View has exactly **one** ViewModel (1:1). View renders state + forwards intents; **no** business logic, HTTP, or parsing in widgets.
- ViewModels invoke use cases and expose state/Commands. Reactive mechanics live in the `state-management` skill.
- Errors cross layers as `Result<T>`, not exceptions (see `error-handling`).

## File placement (SRP: one public class per file, file name = `snake_case` of class)

| Kind | Goes in |
|------|---------|
| Entity | `features/<f>/domain/entities/` |
| Model / DTO | `features/<f>/data/models/` |
| Repository interface | `features/<f>/domain/repositories/` |
| Repository impl | `features/<f>/data/repositories/` |
| Use case | `features/<f>/domain/usecases/` |
| Service | `features/<f>/data/services/` |
| ViewModel / notifier | `features/<f>/presentation/viewmodels/` |
| Page / widget | `features/<f>/presentation/pages/` · `.../widgets/` |
| Shared widget | `lib/shared/widgets/` |
| Theme / constants | `lib/core/theme/` · `lib/core/constants/` (see `theming`) |

## Feature-first tree (one vertical slice per feature)

```
lib/
├── app/        # main.dart, bootstrap.dart (DI), router.dart
├── core/       # theme/, constants/, errors/, utils/  — no feature knowledge
├── shared/     # widgets/, services/ (ApiClient, SecureStorage)
└── features/
    └── auth/
        ├── data/         # models/ services/ repositories/
        ├── domain/       # entities/ repositories/ usecases/
        └── presentation/ # viewmodels/ widgets/ pages/
```

## Common mistakes
- **Logic / API calls / heavy computation in `build()`** → move to a ViewModel/Notifier/repository; `build` only describes UI.
- **Giant deeply-nested widget trees** → extract `const` StatelessWidget components, one per responsibility.
- **Driving a large app with `setState` alone** → choose a real state solution (`state-management`).
- **Hardcoded URLs / API keys / secrets / config literals** → use an `Env`/config layer + `--dart-define`; never commit secrets.
- **God class doing UI + business + data** → split into View / ViewModel / Repository / Service (one responsibility each).
- **Widgets `new`-ing concrete services** → depend on repository *interfaces* injected via DI.
- **Validation / domain rules / API calls inside widgets** → keep them in the domain/data layers.

## Definition of done
Code isn't done until: it **compiles**; `flutter analyze` is **clean** (no new warnings); relevant **tests** are written and pass; **no anti-patterns** from the used skills' checklists remain; the **UI rebuilds** on state change; **controllers/subscriptions are disposed**; it **matches project conventions**; and **no secrets are hardcoded**.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, UI updates, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Full routing rules, multi-skill workflows, and how to dispatch a review subagent: read `reference/orchestration.md`.
- Layer responsibilities, dependency rules, entity-vs-DTO mapping, DI: read `reference/architecture.md`.
- Full folder tree and the file-placement rules table: read `reference/folder-structure.md`.
- A complete small feature across all three layers: read `reference/feature-example.md`.
- Anti-patterns with do/avoid code (build logic, god class, coupling, secrets): read `reference/anti-patterns.md`.
