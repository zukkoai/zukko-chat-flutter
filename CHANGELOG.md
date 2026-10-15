## 0.1.0 - 2026-10-15

Rewrite of the internals and the native chat UI; first release of the Zukko fork. Breaking.

### Breaking

- **Widget API.** The SDK talks to the Zukko chat server's Widget API (`/api/v1/widget`, a *Website* inbox) instead of the Chatwoot Public Client API. `inboxIdentifier` is replaced by `websiteToken` everywhere (`ChatwootClient.create`, `ChatwootChatOptions`, `chatwootSignOut`, `getClientInstanceKey`, `clearData`); existing persisted data of the old API is not reused.
- The session is a JWT from `POST /config` (+ `PATCH /contact/set_user` for an identified user); the old per-call contact/conversation creation, `source_id` and `getConversations()` are gone. `ChatwootContact.contactIdentifier` is the `identifier`; contacts gain `phoneNumber` and a never-serialised `authToken`; `ChatwootConversation` gains `status`, its `contact`/`messages` are optional.
- An `identifierHash` the server rejects fails closed: `INVALID_IDENTIFIER_HASH`, no anonymous fallback, no fetch, no realtime. Any other `set_user` failure of a user with an `identifier` (5xx, timeout, 404, 422) is `IDENTIFY_FAILED`: retryable, the session is not ready (no sends, no realtime) and the banner offers retry. `IDENTITY_NOT_VERIFIED` warns about an `identifier` without `identifierHash`; enforcing identity validation on the inbox is required.
- `ChatwootClient.resume()`; HTTP: no redirects, 15 s / 30 s / 60 s timeouts; `/config` retries back off; uploads over 40 MB are rejected before they are read; `chatwootSignOut`/`clearData` remove a user's records under every `identifierHash`; presence heartbeat every 15 s; `ChatwootUser.toString` hides identity data.
- A resolved conversation no longer wipes the stored conversation and messages (as in the web widget): the status is stored, `onConversationResolved` fires once, the user can keep writing.
- `ChatwootClientExceptionType`: added `SESSION_EXPIRED`, `INVALID_IDENTIFIER_HASH`, `IDENTIFY_FAILED`, `GET_CONFIG_FAILED`; removed the unused `CREATE_CONTACT_FAILED`, `CREATE_CONVERSATION_FAILED`, `GET_CONTACT_FAILED`, `UPDATE_MESSAGE_FAILED`.
- New API: `ChatwootClient.config` (`WidgetConfig`), `setTyping(bool)`, `markSeen()`, `sendMessage(replyTo:)`; callbacks `onConversationUpdated(ChatwootConversation)` and `onSessionReset()`. The native chat sends typing (3 s idle debounce) and read marks, and shows banners for `INVALID_IDENTIFIER_HASH` / `SESSION_EXPIRED` (new `ChatwootL10n.identityRejectedText` / `sessionExpiredText`).
- Attachments go as multipart `message[attachments][]` with client-side size (40 MB) and type checks.
- Realtime: `conversation.created` / `conversation.updated` / `status_changed` events, agent attachments without a refetch, `after=` refetch after a reconnect, a rejected subscription refreshes the session once (rate limited, 3 per minute) before giving up.

- Everything lives under `lib/src`; `package:chatwoot_sdk/chatwoot_sdk.dart` is the only entrypoint. Imports of other library paths (`lib/chatwoot_client.dart`, `lib/ui/...`, `lib/data/...`) stop working.
- `ChatwootClient.create()` completes only after the first contact/conversation refresh; refresh failures arrive through `onError` and are not thrown. It throws an `ArgumentError` for an invalid `baseUrl`.
- `baseUrl` must be `https://`. Plain `http://` is accepted for `localhost`/`127.0.0.1`/`10.0.2.2`, or for any host with the new `allowInsecure: true` (development only), on `ChatwootClient.create` and `ChatwootChatOptions`.
- `ChatwootClient.sendAction` returns `Future<bool>`; `ChatwootActionType.subscribe` is removed (only `update_presence` remains).
- `ChatwootClient.withRepository` is `@visibleForTesting`; Riverpod DI, `ChatwootParameters` and `RepositoryParameters` are removed (the `riverpod` dependency is gone).
- `ChatwootChat` takes `ChatwootChatOptions` (connection and look) plus `ChatwootChatInteractions` (`onEndReached`, `onEndReachedThreshold`, `onMessageLongPress`, `onMessageTap`, `onSendPressed`) and `ChatwootCallbacks`, instead of the former loose parameters. `clientFactory` is test-only.
- `ChatwootChatTheme` is a `ThemeExtension` holding only the style-independent base (brightness, font, optional `accentColor`/`backgroundColor`), derived from the ambient theme; the old color/text-style fields and the `CHATWOOT_*`/`NEUTRAL_*`/`PRIMARY` constants are removed. `ChatwootChatOptions.l10n` is nullable (null follows the app locale) and `ChatwootL10n.poweredByText` is now only the prefix of the "Powered by zukko.ai" footer.
- `ChatwootChat` draws the selected style's header; `ChatwootChat.appBar` still replaces it.
- The SDK is native only: there is no webview widget. Removed: `ChatwootChatDialog` (and `ChatwootChatModal`).
- `ChatwootEvent`, `ChatwootEventType`, `ChatwootAction`, `ChatwootActionData` (public wire classes) are removed; `ChatwootCallbacks` fields are `final`.
- `ChatwootMessage.isMine` is true only for `message_type == 0`; `createdAt` is normalised to ISO-8601 UTC.
- `ChatwootClientException` fields are `final`; new error types `SOCKET_SUBSCRIPTION_REJECTED`, `SOCKET_DISCONNECTED`, `STORAGE_FAILED`. `UPDATE_CONTACT_FAILED`/`UPDATE_MESSAGE_FAILED` are no longer produced (kept for source compatibility).
- Persisted data is AES-encrypted in new `*.enc` boxes (key in the platform keystore); old plaintext boxes are migrated on the first `create()`. `ChatwootUser.identifierHash`/`customAttributes` are never written to disk, and a different `identifierHash` is a different persisted instance.
- New dependency for hosts: `flutter_secure_storage`; `flutter_chat_ui`/`flutter_chat_core` 2.x draws with `material_ui`.
- Minimum SDK: Dart `^3.13.0`, Flutter `>=3.47.0`.

### Added

- `chatwootSignOut(baseUrl:, websiteToken:, user:)`: one call that clears the client's persisted data for a user.
- `ChatwootCallbacks.onConnectionStateChanged(ChatwootConnectionState)`, re-exported `Message` type.
- Native chat styles: `ChatwootChatOptions.style` = `ChatwootChatStyle.smoothSilk` (default), `minimalClean` or `threadFeed`, each in light and dark; image, multi-image, file, audio and link messages; typing indicator.
- `ChatwootChatInteractions.onAttachmentPressed`, `voiceRecording` (`ChatwootVoiceRecordCallbacks`, hold-to-record gesture and timer) and `onMorePressed`; `ChatwootChat.title`.
- Built-in translations: `ChatwootL10n.ru`, `uzLatn`, `uzCyrl`, `tr`, `kaa` and `ChatwootL10n.forLocale`.
- Native chat sends photos, files and hold-to-record voice messages and plays voice messages (`ChatwootChatOptions.enableAttachments`, `enableVoiceMessages`); `ChatwootClient.sendMessage(attachments:)` with `ChatwootUpload`. New dependencies: `record`, `just_audio`, `file_picker`. The style fonts (Manrope, Geist, Onest; Regular and SemiBold, SIL OFL) are bundled in the package, nothing is fetched from Google.
- Realtime: ActionCable handshake with subscribe-on-welcome, 20 s presence, stale watchdog, exponential reconnect, refetch of the messages after the newest known id after a reconnect.

### Fixed

- `clearData`/`clearAllData` deleted nothing or threw `Box not found`; second `clearAllData` hit a disposed container.
- Recovery after 401/403/404 crashed on a null contact, wiped everything on any 404, and left the socket on the dead pubsub token.
- Typing/stopped-typing callbacks were swapped; typing never cleared; presence timer misbehaved; `isMine` counted activity messages.
- Duplicate messages from the server echo; stale messages sorted lexicographically; one malformed item blocked a whole list; huge numbers crashed parsing.
- Native chat crashed in apps that use `flutter/material` only; sends before the client was ready crashed; a late client leaked after dispose.
- The published package lacked the generated `*.g.dart` files (they were gitignored); `.pubignore` now ships them.

### Security

- Data at rest is encrypted; secrets (`source_id`, `pubsub_token`, `identifierHash`) are not logged and not persisted in plaintext.
- https enforced by default; URL path parts are percent-encoded.
- Realtime events are accepted only for the stored conversation and cannot change a message's author or type.
- Strict analysis (`strict-casts`, `strict-inference`, `strict-raw-types`, flutter_lints, `unawaited_futures`, ...) is enforced in CI.

### Toolchain and dependencies

- Targets Flutter 3.47.7 / Dart 3.13.5 (`sdk: ^3.13.0`, `flutter: >=3.47.0`).
- `hive` -> `hive_ce` / `hive_ce_flutter` (existing boxes stay binary-compatible).
- `flutter_chat_ui` 1 -> 2 (plus `flutter_chat_core`, `material_ui`).
- `flutter_secure_storage` 9 -> 11. In 0.0.9 it only held the webview widget cookie, which is gone with the webview; the 0.1.0 encryption key is new, so nothing stored by 9.x needs to be read.
- Example app regenerated: Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Kotlin DSL, iOS 15.0.

### Change notes

| # | Summary | File |
|---|---|---|
| 1 | Added CLAUDE.md with commands, architecture and team rules | [2026-10-13_claude-md-init.md](CHANGELOGS/2026-10-13_claude-md-init.md) |
| 2 | Installed the Flutter and Dart agent skills project-locally | [2026-10-13_flutter-skills-install.md](CHANGELOGS/2026-10-13_flutter-skills-install.md) |
| 3 | Moved code to lib/src, generic storage, Riverpod removed | [2026-10-13_phase1-restructure-storage.md](CHANGELOGS/2026-10-13_phase1-restructure-storage.md) |
| 4 | New ActionCable socket, repository events, interceptor recovery | [2026-10-13_phase2a-socket-realtime.md](CHANGELOGS/2026-10-13_phase2a-socket-realtime.md) |
| 5 | Native chat UI, theme and example rewrite | [2026-10-13_phase2b-ui.md](CHANGELOGS/2026-10-13_phase2b-ui.md) |
| 6 | Encrypted storage and data/core fixes from review and audit | [2026-10-13_phase3a-data-security.md](CHANGELOGS/2026-10-13_phase3a-data-security.md) |
| 7 | UI fixes from review and security audit, new options | [2026-10-13_phase3b-ui-security.md](CHANGELOGS/2026-10-13_phase3b-ui-security.md) |
| 8 | Strict lints, pubspec, unified sign-out, docs | [2026-10-13_phase4-lints-docs-signout.md](CHANGELOGS/2026-10-13_phase4-lints-docs-signout.md) |
| 9 | Verified Widget API contract and migration research doc | [2026-10-13_widget-api-research.md](CHANGELOGS/2026-10-13_widget-api-research.md) |
| 10 | Send photos, files, voice messages; play voice messages | [2026-10-15_attachments-voice.md](CHANGELOGS/2026-10-15_attachments-voice.md) |
| 11 | Seek voice messages by tapping or dragging the waveform | [2026-10-15_audio-seek.md](CHANGELOGS/2026-10-15_audio-seek.md) |
| 12 | CHANGELOG reordered with index table; LICENSE adds Zukko AI 2026 | [2026-10-15_changelog-license-update.md](CHANGELOGS/2026-10-15_changelog-license-update.md) |
| 13 | Three chat styles with shared components and light/dark | [2026-10-15_chat-styles.md](CHANGELOGS/2026-10-15_chat-styles.md) |
| 14 | Example screen with offline demo of the three styles | [2026-10-15_example-styles-demo.md](CHANGELOGS/2026-10-15_example-styles-demo.md) |
| 15 | file_picker bumped to ^13 to fix version resolution | [2026-10-15_fix-file-picker-resolution.md](CHANGELOGS/2026-10-15_fix-file-picker-resolution.md) |
| 16 | Instance-key digest now true FNV-1a 64, works on web | [2026-10-15_fix-web-instance-key-digest.md](CHANGELOGS/2026-10-15_fix-web-instance-key-digest.md) |
| 17 | Full-screen image viewer with Hero, zoom and paging | [2026-10-15_image-viewer-hero.md](CHANGELOGS/2026-10-15_image-viewer-hero.md) |
| 18 | Reviewed six translations, corrected Russian strings | [2026-10-15_l10n-review.md](CHANGELOGS/2026-10-15_l10n-review.md) |
| 19 | Removed webview and dialog; example reduced to styles demo | [2026-10-15_native-only-example-cleanup.md](CHANGELOGS/2026-10-15_native-only-example-cleanup.md) |
| 20 | Removed the old classic chat style and its API | [2026-10-15_remove-old-chat-style.md](CHANGELOGS/2026-10-15_remove-old-chat-style.md) |
| 21 | Design fonts via google_fonts, unused assets removed | [2026-10-15_style-fonts-cleanup.md](CHANGELOGS/2026-10-15_style-fonts-cleanup.md) |
| 22 | Upgraded google_fonts, record, hive_ce, material_ui | [2026-10-15_upgrade-dependencies.md](CHANGELOGS/2026-10-15_upgrade-dependencies.md) |
| 23 | Moved from Public Client API to the Widget API | [2026-10-15_widget-api-migration.md](CHANGELOGS/2026-10-15_widget-api-migration.md) |
| 24 | Bundle style fonts in the package, drop google_fonts | [2026-10-15_bundle-fonts.md](CHANGELOGS/2026-10-15_bundle-fonts.md) |
## Upstream history (Nartey Ephraim, 2021)

Versions below were released by the original author before the Zukko fork.

## [0.0.9] - Jul 22,2021

- Fixed message sending issues
- Adds development docs

## [0.0.8] - Jul 22,2021

- Update dependencies

## [0.0.7] - Jul 22,2021

- Fixed ChatwootChatDialog avatar color
- Fixed ChatwootChatDialog chat bubble overflow

## [0.0.6] - Jul 20,2021

- Fixed received message widget overflow on mobile screens

## [0.0.5] - Jul 20,2021

- Added ChatwootChatModal
- Updated README.md

## [0.0.4] - Jul 15,2021

- Updated build_runner dependency to null safety version

## [0.0.3] - Jul 15,2021

- Fixed multiple Hive adapter registration issue
- Fixed theme background issue
- Resolved pub analysis issues

## [0.0.2] - Jul 15,2021

- Updated example

## [0.0.1] - Jul 15,2021

- Setup initial client sdk flow
