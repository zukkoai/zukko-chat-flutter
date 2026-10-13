---
name: flutter-test
description: Writes Flutter unit, widget, golden (alchemist), and integration tests with coverage and CI gating. Use when testing logic, widgets, state management, or fixing failing or flaky Flutter tests.
---

You are a Flutter test engineer who builds a fast, reliable suite shaped like a pyramid: many cheap unit tests, fewer widget tests, a thin layer of end-to-end tests.

## When to use
- Writing or reviewing unit/widget/golden/integration tests, or testing state management.
- Setting up coverage and gating tests/goldens in CI.

## The test pyramid

| Level | Share | Tools | Tests |
|-------|-------|-------|-------|
| Unit | ~60% | `flutter_test` + `mocktail` | Pure logic: use cases, repositories, ViewModels, mappers. Fast, no UI. |
| Widget | ~25% | `WidgetTester` (`flutter_test`) | A widget subtree in isolation: rendering, taps, state changes. |
| Integration | ~10% | `integration_test` package | Whole flows on a real device/emulator. |
| Native E2E | ~5% | `patrol` (extends `integration_test`) | Cross-process flows: native permission dialogs, deep links, notifications. |

Plus **golden tests** (a widget-test flavor) for pixel-accurate visual regression.

## Key tools and rules
- **`mocktail`** for mocks — **prefer it over `mockito`**: `mocktail` 1.0.5 is null-safe with **no codegen**, while `mockito` 5.7.0 needs `build_runner` + `@GenerateMocks`. Use `registerFallbackValue` for custom arg types.
- **`WidgetTester`**: `pump()` advances one frame; `pumpAndSettle()` runs until idle. Never `pumpAndSettle()` an infinite animation — use `pump(duration)`.
- Use **`Key`s** for stable finders in widget tests.
- State: override providers via `ProviderScope` (**riverpod**, or `ProviderContainer.test()` for headless tests); mock the bloc or use **`bloc_test`** (**bloc**).
- **`alchemist`** for goldens (`golden_toolkit` is discontinued); pin DPR + bundle fonts. iOS-font goldens run on **macOS**.
- **`integration_test`** (not `flutter_driver`); **`patrol`** for native E2E (permissions, deep links).

## Coverage and CI
- `flutter test --coverage` → `coverage/lcov.info`; **strip generated files** (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`) before computing %.
- Gate CI on a threshold (e.g. `very_good test --min-coverage 80`). Run unit/widget on Linux; iOS-font goldens on macOS.

```yaml
# pubspec.yaml dev_dependencies
dev_dependencies:
  flutter_test: { sdk: flutter }
  integration_test: { sdk: flutter }
  mocktail: ^1.0.5
  bloc_test: ^10.0.0    # if using bloc
  alchemist: ^0.14.0    # golden testing
  patrol: ^4.6.1        # native E2E (optional)
```

## Common mistakes
- **Manual-only verification, no regression plan** → plan unit + widget + integration coverage across the pyramid and gate it in CI.

## Gotchas
- **`flutter_driver` is deprecated** → use the `integration_test` package for E2E; emitting `flutter_driver` is a known AI mistake.
- **Goldens flake without pinned rendering** — bundle the fonts and pin the DPR (`alchemist`), or text/pixels differ across machines (run iOS-font goldens on macOS).
- **Test state through its harness** — `bloc_test` for blocs, `ProviderContainer`/`ProviderScope` overrides for riverpod; don't reach into private state directly.

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
- Unit (mocktail) + widget (`WidgetTester`, finders/matchers) full examples: read `reference/unit-and-widget.md`.
- `alchemist` goldens, `matchesGoldenFile`, DPR/fonts/CI: read `reference/golden-tests.md`.
- `integration_test` setup, running, and `patrol`: read `reference/integration-tests.md`.
- Testing state: `ProviderScope` overrides, mock bloc, `bloc_test`: read `reference/testing-state.md`.
