# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude working rules — user mandates, follow exactly

### Git discipline
- **NEVER commit or push without the user's explicit instruction.** No exceptions.
- Commit message template: **`<TASK-ID>: AA - <commit subject>`** (e.g.
  `TSK-1110: AA - capture customer PII into CRM custom_attributes`) — single line,
  English, subject only (detail goes into `CHANGELOGS/`, not the commit body).
- Every change gets a note in `CHANGELOGS/YYYY-MM-DD_<kebab-slug>.md` (`# Title` + short sections, e.g. What / Why or Symptom / Root cause / Fix). `CHANGELOG.md` is the pub.dev release log — separate, don't mix.
- **NEVER add Claude as co-author.** No `Co-Authored-By` trailer in commits, no
  "Generated with Claude Code" footer in PRs. Ever.

### Mandatory agent delegation
When the user asks to **IMPLEMENT** or **RESEARCH** something, you MUST delegate the
work to the matching agency agent(s) via the Agent tool — pick by the prompt's topic:

| Agent | Use for |
|---|---|
| `Frontend Developer` | Vue/React/Angular UI, components, page speed |
| `AI Engineer` | ML models, AI integration, data pipelines |
| `Backend Architect` | API design, DB architecture, scaling |
| `Software Architect` | System design, DDD, architecture decisions |
| `Senior Developer` | Complex implementation, advanced patterns |
| `Code Reviewer` | Code review, security, edge-case hunting |
| `Database Optimizer` | Postgres/MySQL tuning, slow queries, indexing |
| `Performance Benchmarker` | Speed tests, load tests, optimization |
| `Git Workflow Master` | Branch strategy, commits, git history cleanup |
| `UI Designer` | Visual design, component libraries, design systems |
| `UX Architect` | Technical architecture, CSS systems, developer foundations |
| `Mobile App Builder` | Native iOS/Android, cross-platform apps |
| `Trend Researcher` | Market/trend research, community signals |
| `Sprint Prioritizer` | Picking the right thing to build at the right time |
| `Reality Checker` | Feasibility / reality check of an idea |
| `Codebase Onboarding Engineer` | Understanding unfamiliar code, tracing paths across layers |
| `Codebase Archaeologist` | Drift audit after multiple AI tools touched the repo |
| `Minimal Change Engineer` | Smallest viable diff — fixes only what was asked, refuses scope creep |
| `Data Engineer` | ETL/ELT pipelines, lakehouse, data infrastructure |
| `Autonomous Optimization Architect` | API perf shadow-testing with cost/security guardrails |
| `SRE (Site Reliability Engineer)` | SLO/error budgets, observability, toil reduction |
| `UX Researcher` | Usability testing, user behaviour analysis |
| `UI Finish-Gate Reviewer` | Catching generic/unfinished UI before it ships |
| `Accessibility Auditor` | WCAG audit, assistive-technology testing |
| `Evidence Collector` | QA that demands visual proof — screenshots, repro steps |
| `AI-Generated Code Security Auditor` | Secrets, broken access control, prompt injection in AI-written code |
| `Test Automation Engineer` | Playwright E2E, flake elimination, CI parallelization |
| `API Tester` | Endpoint contract validation + load testing |

Trivial one-liner edits may be done directly; anything substantive goes through agents.

---

## Current initiative: Widget API migration

Goal: move this SDK from the Chatwoot Public Client API to the Zukko chat server's Widget API.
Read `doc/ZukkoWidgetSdk.md` before any API/SDK change — verified server contract, plan corrections, gap analysis, open decisions.
Server repo: `/Users/alisherakhmedov/Desktop/Work/microservices/chat`. Plan: `/Users/alisherakhmedov/Desktop/Work/microservices/chat/alisher/plans/flutter_sdk/flutter-sdk-guide.md`.

---

## Commands

Flutter package `chatwoot_sdk` (Dart `^3.13.0`, version 0.1.0). `*.g.dart` is gitignored (json_serializable + hive_ce_generator; the Hive registrar builder is disabled in `build.yaml`), so run codegen after a fresh clone and after changing any `@JsonSerializable`/`@HiveType` model. The analyzer excludes `*.g.dart`. Analysis is strict (`analysis_options.yaml`: flutter_lints, strict-casts/inference/raw-types, `unawaited_futures`, `avoid_print`, ...); `constant_identifier_names` is off on purpose (public enum values keep their wire/UPPER_CASE names).

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # build.yaml limits sources to lib/**; without that, installed pods (example/ios/.symlinks) break it - if it ever fails on them, add --build-filter "lib/**"
flutter test
flutter test test/data/chatwoot_repository_test.dart --plain-name "<test name>"
flutter analyze --fatal-infos
dart pub publish --dry-run
cd example && flutter analyze && flutter test
```

CI (`.github/workflows/develop-actions.yml`, on push/PR to `develop`): `flutter pub get`, `dart run build_runner clean` + `build`, `flutter test`, `flutter analyze --fatal-infos`, `dart pub publish --dry-run`. Run the demo app with `cd example && flutter run` (depends on the package via `path: ../`).

`.pubignore` replaces `.gitignore` for publishing: it must keep shipping `*.g.dart` (the package does not compile without them) and keeps CLAUDE.md, TODO.md, CHANGELOGS/ out.

Running `flutter pub get`/`flutter test` with a newer Flutter rewrites `pubspec.lock`; don't commit incidental changes. Open owner decisions and follow-ups are in `TODO.md`.

## Architecture

`lib/chatwoot_sdk.dart` is the only public entrypoint (exports only); everything under `lib/src/` is internal. `chatwootSignOut` (`src/chatwoot_sign_out.dart`) is the single logout call: `ChatwootClient.clearData` (native) plus `ChatwootWidget.clearStoredConversation` (webview token + web storage). Two independent ways to embed Chatwoot:

1. **Webview widget** (`src/ui/webview/`): `ChatwootWidget` (loads the Chatwoot web widget with `webview_flutter`; no client/storage). Pure, unit-tested `bridge.dart` (JS escaping, navigation rules: only `/widget` stays in the main frame, other links go to the OS browser; `isWidgetPage`; JWT-shaped token check; token scope key); conversation token lives in an injectable `ChatwootTokenStore` scoped per baseUrl+websiteToken+user. Each load captures its own scope; bridge messages are honoured only from the current load while the webview shows `/widget`, `loaded` once per load. A target/user switch and `clearStoredConversation` (the sign-out call) also wipe the webview's cookies, local storage and cache. `baseUrl` goes through `validateBaseUrl` (`allowInsecure` param).
2. **Native client**: `ChatwootClient` + UI in `src/ui/chat/`: `ChatwootChatController` (ChangeNotifier; owns client lifecycle, echoId->id dedupe, queue-until-ready; a failed start marks queued sends failed and the view shows an error banner with retry) -> `ChatwootChatView` <- thin `ChatwootChat` page / `ChatwootChatDialog`, configured by `ChatwootChatOptions` (connection, look) and `ChatwootChatInteractions` (UI callbacks); `callbacks` are kept current across rebuilds. Looks live in `styles/` (`ChatwootChatStyle`, one file per style). `ChatwootChatTheme` is a `ThemeExtension` derived from the ambient `ColorScheme`. flutter_chat_ui uses `material_ui`, so the view wraps it in material_ui `Theme`/`Material`. Tests inject a fake via `clientFactory`.

Layout: `src/core/` (client, callbacks, exception) -> `src/data/chatwoot_repository.dart` -> `src/data/remote/api/` (Dio REST: `apiCall` helper, auth service, interceptor, `ChatwootClientService`) + `src/data/remote/realtime/` (socket, frames, events) and `src/data/local/` (`LocalStorage`). `src/data/models/` holds the Hive+JSON models, `src/shared/` the JSON converters and debug logger. Results are never returned to callers; the repository pushes them through `ChatwootCallbacks`. `ChatwootClient.create()` is the only factory: it opens Hive (if persistence is on), wires everything by constructor injection (no DI framework), awaits `repository.initialize()` (refresh contact + conversation, then `listenForEvents()`; failures go to `onError`, never thrown). The one thing `create()` throws is an `ArgumentError` for a bad `baseUrl` (`shared/url_policy.dart`: https only; http for loopback/10.0.2.2 or `allowInsecure`). If `openDB()` fails (keystore, path_provider, a foreign Hive adapter on typeIds 0-4) it reports `STORAGE_FAILED` via `onError` and runs on `LocalStorage.inMemory()`.

Non-obvious points:

- **Each client owns its repository, storage and two Dios**; `dispose()` is idempotent and closes the Dios. Non-persisted clients never share state. Persisted clients with the same `clientInstanceKey` (`chatwootInstanceKey`: escaped `baseUrl|||userIdentifier|||inboxIdentifier`, no user = empty segment) share the same Hive records.
- **Persistence is optional** (`enablePersistence`): `LocalStorage.persisted(key)` (Hive) or `LocalStorage.inMemory()`. Contact/conversation/user are `SingleStore<T>`; messages are `ChatwootMessagesDao` (oldest first in both). Hive boxes are shared by all instances and stay open for the process lifetime; every record is keyed by the instance key (messages `<key>|m|<id>`; with a user `identifierHash` the key gets a `|||h:<digest>` segment). The boxes are AES-encrypted (`HiveAesCipher`, 256-bit key generated once and kept by `ChatwootKeyStore`, i.e. flutter_secure_storage; tests swap `LocalStorage.keyStore` for a fake) and live under the `*.enc` names; `ChatwootUser.identifierHash`/`customAttributes` are never written to disk (`HiveUserStore`). `LocalStorage.openDB()` is idempotent and serialised (a lock) and moves records of the earlier plaintext boxes (<= 0.0.9 entity-id keys + index boxes, or unencrypted instance-keyed boxes) into the encrypted ones; a record it cannot attribute stays in the old box untouched.
- **Hive**: typeIds in `data/local/hive_type_ids.dart` (contact 0, conversation 1, message 2, user 3, event-message-user 4), registered once by `registerChatwootAdapters()`. Box names are pinned string literals in `ChatwootBoxNames` (they are file names on devices; never rename, the `legacy*` ones are what the migration reads). A foreign adapter on our typeIds makes `registerChatwootAdapters()` throw `STORAGE_FAILED`. New `@HiveType` models need a new unique id; never reuse/renumber.
- **Auth**: `ChatwootClientApiInterceptor` (authenticated Dio) lazily creates the contact/conversation via `ChatwootClientAuthService` (unauthenticated Dio), stores them, and fills the `{INBOX_IDENTIFIER}`/`{CONTACT_IDENTIFIER}`/`{CONVERSATION_IDENTIFIER}` placeholders with `Uri.encodeComponent`ed values; a contact without a usable `source_id` (empty, > 256 chars, `.`/`..`) is rejected with a typed error. Recovery: 401/403, or 404 on a contact/conversations path, resets contact + conversation; 404 on a messages path resets only the conversation; at most 3 resets per minute.
- **Realtime**: `ChatwootSocket` (`data/remote/realtime/chatwoot_socket.dart`, pure Dart, injectable channel factory/backoff) owns the ActionCable connection to `<baseUrl as ws>/cable`: handshake (subscribe on `welcome`, `RoomChannel` + `pubsub_token`), 20 s `update_presence`, 6 s stale watchdog, exponential reconnect (1 s..30 s + jitter), one teardown path; the pubsub token comes from a `tokenProvider` read on every open, and the interceptor's `onSessionReset` makes the repository call `reconnectIfTokenChanged()`; `Frame.parse` never throws. It emits `SocketEvent`s; the repository maps them to callbacks (typing 30 s auto-clear, presence 40 s reset, echo dedupe, latest-page refetch after a reconnect) and disposes the socket before storage. `ChatwootClientService` is REST only. Apps can observe `ChatwootCallbacks.onConnectionStateChanged`.
- `ChatwootClientException` / `ChatwootClientExceptionType` is the single error type; `apiCall` maps every REST failure (transport, status, malformed body) to it; failed sends carry the `echoId` in `data`.

## Tests

`test/` mirrors `lib/src/`. No codegen is needed for tests (hand-written fakes, no mockito). Helpers in `test/utils/`: `hive_test_env.dart` (real Hive in a unique temp dir per file via a fake `PathProviderPlatform`, plus `FakeKeyStore`; call `setUpAll`/`tearDown`/`tearDownAll`), `fixtures.dart` (contact/conversation/message/user builders), `fakes.dart` (`FakeClientService`, `FakeChannel`), `fake_http.dart` (Dio on a scripted adapter), `fake_chat_server.dart` (real loopback HTTP server for `ChatwootClient.create` wiring). `test/ui/webview/fake_webview_platform.dart` is a recording fake `WebViewPlatform` (controller, cookie manager, event log). Storage tests run one suite against both the Hive and in-memory implementations. Timers (socket, typing, presence) are tested with `fake_async`; widget tests pump explicitly. Only the Hive/temp-dir and loopback-server tests touch real IO.
