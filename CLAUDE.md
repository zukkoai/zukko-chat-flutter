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

## Widget API (done, 0.1.0)

The SDK speaks the Zukko chat server's Widget API (`/api/v1/widget`, a Website inbox, `websiteToken`). Verified server contract, decisions and remaining gaps: `doc/ZukkoWidgetSdk.md`; open items: `TODO.md`; migration note: `CHANGELOGS/2026-10-15_widget-api-migration.md`.
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

`lib/chatwoot_sdk.dart` is the only public entrypoint (exports only); everything under `lib/src/` is internal. `chatwootSignOut` (`src/chatwoot_sign_out.dart`) is the logout call (`ChatwootClient.clearData`). The SDK is native only (the webview widget and the dialog were removed):

**Native client**: `ChatwootClient` (`create(baseUrl, websiteToken, user?)`) + UI in `src/ui/chat/`: `ChatwootChatController` (ChangeNotifier; owns client lifecycle, echoId->id dedupe, queue-until-ready; a failed start marks queued sends failed and the view shows an error banner with retry) -> `ChatwootChatView` <- thin `ChatwootChat` page, configured by `ChatwootChatOptions` (connection, look) and `ChatwootChatInteractions` (UI callbacks); `callbacks` are kept current across rebuilds. Chat styles: `ChatwootChatStyle` enum + the `ChatStyle` contract in `ui/chat/chatwoot_chat_style.dart` (header, composer, typing indicator, footer, message `Builders`); implementations in `ui/chat/styles/<name>/` (`smooth_silk`, `minimal_clean`, `thread_feed`: `<name>_style.dart` entry, `<name>_tokens.dart` light/dark tokens built by `<Name>Tokens.from(ChatwootChatTheme)`, `widgets/`); shared style-agnostic parts in `ui/chat/components/` (composer shell, voice recorder = hold/timer/cancel + `record` PCM capture -> WAV `ChatwootUpload`, `AudioPlaybackController` (just_audio, one per view, passed to styles via `ChatMessageEnv.audio`), audio player bar, attachment picker (file_picker sheet), image grid, full-screen image viewer (`ChatImageTap` = Hero + tap, `openImageViewer`; Hero tag `chatwoot-image-<messageId>-<index>`), link preview, linkified text, typing indicator, powered-by). Sending files: `ChatwootChatController.sendAttachments` (local preview, outbox for resend, replaced by the server version on confirm) -> `ChatwootClient.sendMessage(attachments:)` -> repository -> `ChatwootClientService.createMessage` (multipart `message[attachments][]`; the interceptor replays a cloned `FormData`). Style folders import only the contract, `components/`, theme and l10n, never data/client. Theme flow: app `ThemeData` -> `ChatwootChatTheme` (`ThemeExtension`: brightness, optional font/accent/background overrides; design fonts Manrope/Geist/Onest are bundled as package fonts in `assets/fonts/<family>/` with their OFL.txt, used as `packages/chatwoot_sdk/<Family>`, regular + SemiBold only, so a new weight in a style needs its TTF added) -> style tokens; `ChatwootChatView` resolves it once per build. The composer is drawn by the view under the flutter_chat_ui list (its own composer slot is empty). Multi-image messages are a `CustomMessage` read via `GalleryMessage`. `ChatwootL10n` has en/ru/uzLatn/uzCyrl/tr/kaa; `options.l10n == null` follows the locale. flutter_chat_ui uses `material_ui`, so the view wraps it in material_ui `Theme`/`Material`. Tests inject a fake via `clientFactory`. `example/` is only the styles demo (`StylesDemoScreen`, offline `DemoChatwootClient`).

Layout: `src/core/` (client, callbacks, exception) -> `src/data/chatwoot_repository.dart` -> `src/data/remote/api/` (Dio REST: `apiCall` helper, `WidgetSession`, `WidgetAuthInterceptor`, `WidgetConfig`, `widget_message_form.dart`, `ChatwootClientService`) + `src/data/remote/realtime/` (socket, frames, events) and `src/data/local/` (`LocalStorage`). `src/data/models/` holds the Hive+JSON models, `src/shared/` the JSON converters and debug logger. Results are never returned to callers; the repository pushes them through `ChatwootCallbacks`. `ChatwootClient.create()` is the only factory: it opens Hive (if persistence is on), wires everything by constructor injection (no DI framework), awaits `repository.initialize()` (session start, `GET /conversations`, then `listenForEvents()`; failures go to `onError`, never thrown). The one thing `create()` throws is an `ArgumentError` for a bad `baseUrl` (`shared/url_policy.dart`: https only; http for loopback/10.0.2.2 or `allowInsecure`). If `openDB()` fails (keystore, path_provider, a foreign Hive adapter on typeIds 0-4) it reports `STORAGE_FAILED` via `onError` and runs on `LocalStorage.inMemory()`.

Non-obvious points:

- **Each client owns its repository, storage and two Dios**; `dispose()` is idempotent and closes the Dios. Non-persisted clients never share state. Persisted clients with the same `clientInstanceKey` (`chatwootInstanceKey`: escaped `baseUrl|||userIdentifier|||websiteToken`, no user = empty segment) share the same Hive records.
- **Persistence is optional** (`enablePersistence`): `LocalStorage.persisted(key)` (Hive) or `LocalStorage.inMemory()`. Contact/conversation/user are `SingleStore<T>`; messages are `ChatwootMessagesDao` (oldest first in both). Hive boxes are shared by all instances and stay open for the process lifetime; every record is keyed by the instance key (messages `<key>|m|<id>`; with a user `identifierHash` the key gets a `|||h:<digest>` segment). The boxes are AES-encrypted (`HiveAesCipher`, 256-bit key generated once and kept by `ChatwootKeyStore`, i.e. flutter_secure_storage; tests swap `LocalStorage.keyStore` for a fake) and live under the `*.enc` names; `ChatwootUser.identifierHash`/`customAttributes` are never written to disk (`HiveUserStore`). `LocalStorage.openDB()` is idempotent and serialised (a lock) and moves records of the earlier plaintext boxes (<= 0.0.9 entity-id keys + index boxes, or unencrypted instance-keyed boxes) into the encrypted ones; a record it cannot attribute stays in the old box untouched.
- **Hive**: typeIds in `data/local/hive_type_ids.dart` (contact 0, conversation 1, message 2, user 3, event-message-user 4), registered once by `registerChatwootAdapters()`. Box names are pinned string literals in `ChatwootBoxNames` (they are file names on devices; never rename, the `legacy*` ones are what the migration reads). A foreign adapter on our typeIds makes `registerChatwootAdapters()` throw `STORAGE_FAILED`. New `@HiveType` models need a new unique id; never reuse/renumber.
- **Auth / session**: `WidgetSession` (bare Dio, no interceptors) owns JWT + contact + pubsub token: `POST /config` (sends the saved JWT; the server mints a new JWT every call, returns the contact and the only `pubsub_token`), then for an identified user `PATCH /contact/set_user` (+ `GET /contact`; a `widget_auth_token` in the answer, or a contact id that differs from the stored one, triggers one more `/config`) and the stored contact mirrors the identity. A 401 on `set_user` fails closed (`INVALID_IDENTIFIER_HASH`, terminal, no anonymous fallback); for a user with an `identifier` ANY other `set_user`/`GET /contact` failure is `IDENTIFY_FAILED` (retryable: the session stays not ready, no sends, no socket); a user without identifier only gets a warning; identifier without hash reports `IDENTITY_NOT_VERIFIED` once. A failed `start()` backs off 2 s, 4 s ... 60 s (rethrows the last error without a request), each rebuild has a 90 s backstop timeout, the `widget_auth_token` of `set_user` is only passed to the follow-up `/config` (never stored first), a rebuild that replaced the contact and then failed still bumps the generation and fires `onSessionReset`, and genuine 404 probes (same contact) do not use the 3-per-minute budget. Both Dios come from `shared/http_client.dart` (`chatwootDio`: no redirects, 15/30/60 s timeouts). The JWT is `ChatwootContact.authToken` (`@HiveField(5)`, in the encrypted contacts box only; never in JSON, logs or `toString`). `WidgetAuthInterceptor` (authenticated Dio) adds `website_token` + `X-Auth-Token`; on 404 (also what a stale JWT gives) it asks `session.recoverFrom404`: `/config` with the current JWT returning the same contact means a genuine 404 (passed through), another contact means a new session (conversation/messages cleared, `onSessionReset`, request replayed once on the same Dio). Typing and last-seen calls are `noRecover`. All session entry points share one lock; rebuilds are limited to 3 per minute, then `SESSION_EXPIRED`. Resolved conversations are never wiped.
- **Realtime**: `ChatwootSocket` (`data/remote/realtime/chatwoot_socket.dart`, pure Dart, injectable channel factory/backoff) owns the ActionCable connection to `<baseUrl as ws>/cable`: handshake (subscribe on `welcome`, `RoomChannel` + `pubsub_token`), 15 s `update_presence` (server window 20 s), 6 s stale watchdog, exponential reconnect (1 s..30 s + jitter), a confirm timeout twice in a row or a `reject_subscription` stops it with `SOCKET_SUBSCRIPTION_REJECTED` (the repository then calls `session.refresh(socketRejected)`: a new pubsub token reconnects, the same one leaves it closed, reports once and retries after 60 s, 120 s ... 10 min and on `resume()`; stops on dispose/fail-closed), one teardown path; the pubsub token comes from a `tokenProvider` read on every open, and the session's `onSessionReset` makes the repository call `reconnectIfTokenChanged()`, fire `ChatwootCallbacks.onSessionReset` (the controller drops every server message, keeping unsent ones) and refetch conversation + latest messages; `Frame.parse` never throws. It emits `SocketEvent`s; the repository maps them to callbacks (typing 30 s auto-clear, presence 40 s reset, echo dedupe, `GET /messages?after=<newest received id>` on every subscription (cursor = fetched/event messages only, never ids of our own sends; at most 20 pages of 100), `conversation.created/updated/status_changed` -> stored `{id, inboxId, status}` + `onConversationUpdated`, realtime attachments) and disposes the socket before storage. `ChatwootClientService` is REST only (messages before/after, conversation, createMessage JSON or multipart `message[attachments][]`, toggle_typing, update_last_seen). Typing is REST (`setTyping`, 3 s idle debounce in the controller); the controller calls `markSeen` on open and on incoming messages while visible. Apps can observe `ChatwootCallbacks.onConnectionStateChanged`.
- `ChatwootClientException` / `ChatwootClientExceptionType` is the single error type; `apiCall` maps every REST failure (transport, status, malformed body) to it; failed sends carry the `echoId` in `data`.

## Tests

`test/` mirrors `lib/src/`. No codegen is needed for tests (hand-written fakes, no mockito). Helpers in `test/utils/`: `hive_test_env.dart` (real Hive in a unique temp dir per file via a fake `PathProviderPlatform`, plus `FakeKeyStore`; call `setUpAll`/`tearDown`/`tearDownAll`), `fixtures.dart` (contact/conversation/message/user builders), `fakes.dart` (`FakeClientService`, `FakeChannel`), `fake_http.dart` (Dio on a scripted adapter), `scripted_widget.dart` (`ScriptedWidget` + `WidgetRig`: session/interceptor/service on a scripted adapter), `fake_chat_server.dart` (real loopback HTTP server for `ChatwootClient.create` wiring). Storage tests run one suite against both the Hive and in-memory implementations. Timers (socket, typing, presence) are tested with `fake_async`; widget tests pump explicitly. Only the Hive/temp-dir and loopback-server tests touch real IO.
