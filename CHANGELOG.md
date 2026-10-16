## 0.1.0 - 2026-10-15

First release of the Zukko fork: a native chat UI on the Zukko Chat Widget API, rebuilt from the Chatwoot SDK. Breaking.

### Breaking

- Package renamed `chatwoot_sdk` -> `zukko_chat_flutter`; public classes `Chatwoot*` -> `ZukkoChat*` (`ChatwootClient` -> `ZukkoChatClient`, `chatwootSignOut` -> `zukkoChatSignOut`).
- Talks to the Widget API: `websiteToken` replaces `inboxIdentifier`; data stored by the old API is not reused.
- Identified users need `identifierHash` (HMAC from your backend); a rejected hash fails closed (`INVALID_IDENTIFIER_HASH`, no anonymous fallback).
- Native only: the webview widget and `ChatwootChatDialog` are removed.
- Single entrypoint `package:zukko_chat_flutter/zukko_chat_flutter.dart`; other library paths stop working.
- Enum values are lowerCamelCase with unchanged wire codes (`ZukkoChatExceptionType.storageFailed.wire == 'STORAGE_FAILED'`).
- `baseUrl` must be `https://` (plain `http://` only for localhost or with `allowInsecure: true`).
- Minimum Dart `^3.13.0`, Flutter `>=3.47.0`.

### Added

- Three chat styles (`smoothSilk`, `minimalClean`, `threadFeed`), each in light and dark.
- Photos, files and hold-to-record voice messages; voice playback with seek.
- Six built-in languages (en, ru, uz Latin, uz Cyrillic, tr, kaa) following the app locale.
- Realtime over ActionCable with reconnect and catch-up of missed messages.
- Older history loads 20 messages at a time on scroll.
- Link previews (`enableLinkPreviews`).
- Connection banner (no internet / connecting).
- Send limits with warnings (150 000 characters, 15 files, 40 MB).
- `zukkoChatSignOut` clears a user's local data in one call.
- Encrypted local storage.

### Security

- Data at rest is AES-encrypted; the key lives in Keychain/Keystore.
- The JWT and other secrets are never logged.
- https is enforced by default.
- The HMAC secret never ships in the app; only the hash computed by your backend does.

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
| 12 | Bundle style fonts in the package, drop google_fonts | [2026-10-15_bundle-fonts.md](CHANGELOGS/2026-10-15_bundle-fonts.md) |
| 13 | CHANGELOG reordered with index table; LICENSE adds Zukko AI 2026 | [2026-10-15_changelog-license-update.md](CHANGELOGS/2026-10-15_changelog-license-update.md) |
| 14 | Three chat styles with shared components and light/dark | [2026-10-15_chat-styles.md](CHANGELOGS/2026-10-15_chat-styles.md) |
| 15 | CI tests on every branch, tag and publish to pub.dev from main | [2026-10-15_ci-cd-pubdev-release.md](CHANGELOGS/2026-10-15_ci-cd-pubdev-release.md) |
| 16 | Example app id changed to ai.zukko.chat.sdk | [2026-10-15_example-app-id.md](CHANGELOGS/2026-10-15_example-app-id.md) |
| 17 | Example app rework | [2026-10-15_example-rework.md](CHANGELOGS/2026-10-15_example-rework.md) |
| 18 | Example screen with offline demo of the three styles | [2026-10-15_example-styles-demo.md](CHANGELOGS/2026-10-15_example-styles-demo.md) |
| 19 | file_picker bumped to ^13 to fix version resolution | [2026-10-15_fix-file-picker-resolution.md](CHANGELOGS/2026-10-15_fix-file-picker-resolution.md) |
| 20 | Instance-key digest now true FNV-1a 64, works on web | [2026-10-15_fix-web-instance-key-digest.md](CHANGELOGS/2026-10-15_fix-web-instance-key-digest.md) |
| 21 | Gitignore cleanup | [2026-10-15_gitignore-cleanup.md](CHANGELOGS/2026-10-15_gitignore-cleanup.md) |
| 22 | Full-screen image viewer with Hero, zoom and paging | [2026-10-15_image-viewer-hero.md](CHANGELOGS/2026-10-15_image-viewer-hero.md) |
| 23 | Internal rename to zukko_chat and shared helpers | [2026-10-15_internal-rename-and-shared-helpers.md](CHANGELOGS/2026-10-15_internal-rename-and-shared-helpers.md) |
| 24 | Reviewed six translations, corrected Russian strings | [2026-10-15_l10n-review.md](CHANGELOGS/2026-10-15_l10n-review.md) |
| 25 | Removed webview and dialog; example reduced to styles demo | [2026-10-15_native-only-example-cleanup.md](CHANGELOGS/2026-10-15_native-only-example-cleanup.md) |
| 26 | README reset | [2026-10-15_readme-reset.md](CHANGELOGS/2026-10-15_readme-reset.md) |
| 27 | Removed the old classic chat style and its API | [2026-10-15_remove-old-chat-style.md](CHANGELOGS/2026-10-15_remove-old-chat-style.md) |
| 28 | Public API and package renamed to Zukko | [2026-10-15_rename-public-api-zukko.md](CHANGELOGS/2026-10-15_rename-public-api-zukko.md) |
| 29 | Review fixes: core, data, shared | [2026-10-15_review-fixes-data.md](CHANGELOGS/2026-10-15_review-fixes-data.md) |
| 30 | Review fixes: chat styles | [2026-10-15_review-fixes-styles.md](CHANGELOGS/2026-10-15_review-fixes-styles.md) |
| 31 | Review fixes: chat UI, controller, components, l10n | [2026-10-15_review-fixes-ui.md](CHANGELOGS/2026-10-15_review-fixes-ui.md) |
| 32 | Design fonts for the chat styles, unused assets removed | [2026-10-15_style-fonts-cleanup.md](CHANGELOGS/2026-10-15_style-fonts-cleanup.md) |
| 33 | Upgraded dependencies to latest stable | [2026-10-15_upgrade-dependencies.md](CHANGELOGS/2026-10-15_upgrade-dependencies.md) |
| 34 | Moved from Public Client API to the Widget API | [2026-10-15_widget-api-migration.md](CHANGELOGS/2026-10-15_widget-api-migration.md) |
| 35 | Connection banner for no internet and connecting | [2026-10-16_connection-status-banner.md](CHANGELOGS/2026-10-16_connection-status-banner.md) |
| 36 | Header status taken from the conversation status | [2026-10-16_header-status-from-conversation-status.md](CHANGELOGS/2026-10-16_header-status-from-conversation-status.md) |
| 37 | Older history loads lazily, 20 messages at a time | [2026-10-16_lazy-older-history-paging.md](CHANGELOGS/2026-10-16_lazy-older-history-paging.md) |
| 38 | Link previews in messages | [2026-10-16_link-previews.md](CHANGELOGS/2026-10-16_link-previews.md) |
| 39 | Local voice playback and clear send status | [2026-10-16_local-voice-playback-and-send-status.md](CHANGELOGS/2026-10-16_local-voice-playback-and-send-status.md) |
| 40 | Localization audit of the built-in languages | [2026-10-16_localization-audit.md](CHANGELOGS/2026-10-16_localization-audit.md) |
| 41 | Hide mic when audio is off; warn on send limits | [2026-10-16_mic-flag-and-send-limits.md](CHANGELOGS/2026-10-16_mic-flag-and-send-limits.md) |
| 42 | New text for the resolved conversation line | [2026-10-16_resolved-line-text.md](CHANGELOGS/2026-10-16_resolved-line-text.md) |
| 43 | Storage cleanups: copies, typed attachments, type ids | [2026-10-16_storage-cleanups.md](CHANGELOGS/2026-10-16_storage-cleanups.md) |
| 44 | Tooling: packages, git hygiene, lint naming | [2026-10-16_tooling-packages-lints.md](CHANGELOGS/2026-10-16_tooling-packages-lints.md) |

## Upstream history

Versions 0.0.1-0.0.9 (2021) were released by the original author, Nartey Ephraim, before the Zukko fork.
