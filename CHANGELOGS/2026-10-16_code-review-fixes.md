# Code review fixes (2026-10-16)

## Data / core / shared

### Initial conversation status reported after dispose
- **Symptom:** `onConversationUpdated` could fire on a disposed client.
- **Root cause:** `_syncConversation` called the callback after awaits without checking `_disposed`.
- **Fix:** guard with `if (!_disposed)`. Test: `initialize reports the initial conversation, but not after dispose` (fake service got a `conversationGate`).

## UI components: link preview parsing and unsupported message style

### Hostile HTML entities dropped the whole link preview
- Symptom: a page with `&#99999999999;` or `&#xD800;` in og tags produced no preview.
- Root cause: `int.parse` / `String.fromCharCode` threw on out-of-range or surrogate code points.
- Fix: `_decodeEntities` uses `int.tryParse` and a range check (replaced by a space).

### Title / description cut inside an emoji
- Symptom: a length-capped text could end in a lone surrogate half.
- Root cause: `substring(0, max)` on UTF-16 units.
- Fix: the cut steps back one unit when it would split a surrogate pair.

### Unsupported message text had no style
- Symptom: `unsupportedMessageBuilder` showed the text in the default (unthemed) style.
- Root cause: bare `Text(...)`.
- Fix: uses the style's `tokens.body`.

## UI chat top-level: connection monitor, controller, view

### Duplicate DNS recheck loops
- **Symptom**: after a quick drop/recover/drop, the host was probed twice as often (two loops).
- **Root cause**: a probe already running when the state flipped re-armed the timer on return, overwriting the new loop's timer.
- **Fix**: `ChatConnectionMonitor` epoch counter; a stale probe result is dropped. Test: `chat_connection_monitor_test.dart`.

### Throwing `onBackOnline` stopped the rechecks
- **Symptom**: if `client.resume()` threw, no further probes ran and the banner could stick.
- **Root cause**: the next timer was armed after the callback.
- **Fix**: arm the timer first, guard the callback with try/catch. Test added.

### Web / empty host showed "offline" forever
- **Symptom**: `InternetAddress.lookup` is unsupported on web (and fails for an empty host), so the banner stayed on "No internet".
- **Fix**: `resolvesHost` returns true on web or for an empty host. Test for the empty host.

### Late old client cleared the new client's first-page flag
- **Symptom**: after `retry()`, a replaced client's `loadMessages` finishing late reset `_awaitingLatest`, so a short first page never set `_hasMore = false` (useless extra "older" request).
- **Fix**: `_start` returns early when its generation was replaced. Test in `zukko_chat_controller_paging_test.dart`.

### Voice flag stale after the connection options changed
- **Symptom**: a new controller (changed baseUrl/token) kept the previous inbox's "audio allowed" value until the new session loaded.
- **Fix**: `_serverAllowsAudio` reset to true when the controller is recreated in `ZukkoChatView.didUpdateWidget`.

### Message limit counted UTF-16 units
- Symptom: emoji-heavy text was blocked before the server's 150 000 limit.
- Root cause: `String.length` counts UTF-16 units; Rails counts code points.
- Fix: composer compares `runes.length` (only computed when `length` is over the limit).

### Relative og:image resolved against the original URL
- Symptom: after a cross-host redirect the image URL pointed to the wrong host.
- Root cause: `parseLinkPreview` resolved against the requested URI.
- Fix: the fetcher passes `res.realUri` as `resolveAgainst`; `link` stays the original URL.
