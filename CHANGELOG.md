## 1.0.0 - 2026-10-17

First release.

### Added

- Native chat screen `ZukkoChat` for the Zukko Chat Widget API, plus a headless `ZukkoChatClient`.
- Three chat styles (`smoothSilk`, `minimalClean`, `threadFeed`), each in light and dark, with bundled fonts.
- Text, photos, files and hold-to-record voice messages; voice playback with seek and the real length shown before playing.
- Attachment sheet and voice-recording view designed for each style.
- Markdown in agent and AI messages (bold, italic, code, lists, headings, links, quotes, tables); the visitor's own messages stay plain.
- Link previews (`enableLinkPreviews`).
- Realtime updates with automatic reconnect and catch-up of missed messages.
- Opens with the newest 20 messages; older history loads 20 at a time on scroll to the top.
- Auto-scroll to new replies when the list is near the bottom or right after sending.
- Connection banner (no internet / connecting).
- Send limits with warnings (150 000 characters, 15 files, 40 MB per file).
- Six built-in languages (en, ru, uz Latin, uz Cyrillic, tr, kaa) following the app locale.
- User identity with `ZukkoChatUser` and `identifierHash`; one call to sign out (`zukkoChatSignOut`).
- Debug-only log with levels (`ERROR`, `WARNING`, info).

### Security

- The session token (JWT) is stored only in an AES-encrypted local database; the key lives in Keychain/Keystore.
- Tokens and hashes are never logged.
- `baseUrl` must be `https://` (plain `http://` is rejected, also for localhost); the socket uses `wss://`.
- The HMAC secret never ships in the app; only the hash computed by your backend does. A rejected hash fails closed (`INVALID_IDENTIFIER_HASH`).

### Requirements

- Dart `^3.13.0`, Flutter `>=3.47.0`, iOS 15.0+, Android 7.0 (API 24)+.
