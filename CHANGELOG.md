## [0.0.1] - Jul 15,2021

- Setup initial client sdk flow

## [0.0.2] - Jul 15,2021

- Updated example

## [0.0.3] - Jul 15,2021

- Fixed multiple Hive adapter registration issue
- Fixed theme background issue
- Resolved pub analysis issues

## [0.0.4] - Jul 15,2021

- Updated build_runner dependency to null safety version

## [0.0.5] - Jul 20,2021

- Added ChatwootChatModal
- Updated README.md

## [0.0.6] - Jul 20,2021

- Fixed received message widget overflow on mobile screens

## [0.0.7] - Jul 22,2021

- Fixed ChatwootChatDialog avatar color
- Fixed ChatwootChatDialog chat bubble overflow

## [0.0.8] - Jul 22,2021

- Update dependencies

## [0.0.9] - Jul 22,2021

- Fixed message sending issues
- Adds development docs

## 0.1.0

Rewrite of the internals, the native chat UI and the webview widget. Breaking.

### Breaking

- Everything lives under `lib/src`; `package:chatwoot_sdk/chatwoot_sdk.dart` is the only entrypoint. Imports of other library paths (`lib/chatwoot_client.dart`, `lib/ui/...`, `lib/data/...`) stop working.
- `ChatwootClient.create()` completes only after the first contact/conversation refresh; refresh failures arrive through `onError` and are not thrown. It throws an `ArgumentError` for an invalid `baseUrl`.
- `baseUrl` must be `https://`. Plain `http://` is accepted for `localhost`/`127.0.0.1`/`10.0.2.2`, or for any host with the new `allowInsecure: true` (development only), on `ChatwootClient.create`, `ChatwootChatOptions` and `ChatwootWidget`.
- `ChatwootClient.sendAction` returns `Future<bool>`; `ChatwootActionType.subscribe` is removed (only `update_presence` remains).
- `ChatwootClient.withRepository` is `@visibleForTesting`; Riverpod DI, `ChatwootParameters` and `RepositoryParameters` are removed (the `riverpod` dependency is gone).
- `ChatwootChat` and `ChatwootChatDialog` take `ChatwootChatOptions` (connection and look) plus `ChatwootChatInteractions` (`onEndReached`, `onEndReachedThreshold`, `onMessageLongPress`, `onMessageTap`, `onSendPressed`) and `ChatwootCallbacks`, instead of the former loose parameters. `ChatwootChatDialog.show` takes the same. `clientFactory` is test-only.
- `ChatwootChatTheme` is a `ThemeExtension` derived from the ambient `ColorScheme`; the ~35 unused parameters and the `CHATWOOT_*`/`NEUTRAL_*`/`PRIMARY` constants are removed. `ChatwootL10n` keeps only keys that are used (new: `connectionErrorText`, `retryLabel`).
- `ChatwootEvent`, `ChatwootEventType`, `ChatwootAction`, `ChatwootActionData` (public wire classes) are removed; `ChatwootCallbacks` fields are `final`.
- `ChatwootMessage.isMine` is true only for `message_type == 0`; `createdAt` is normalised to ISO-8601 UTC.
- `ChatwootClientException` fields are `final`; new error types `SOCKET_SUBSCRIPTION_REJECTED`, `SOCKET_DISCONNECTED`, `STORAGE_FAILED`. `UPDATE_CONTACT_FAILED`/`UPDATE_MESSAGE_FAILED` are no longer produced (kept for source compatibility).
- `ChatwootWidget.clearStoredConversation` also wipes the webview's cookies, local storage and cache. The old global `cwCookie` token is no longer read.
- Persisted data is AES-encrypted in new `*.enc` boxes (key in the platform keystore); old plaintext boxes are migrated on the first `create()`. `ChatwootUser.identifierHash`/`customAttributes` are never written to disk, and a different `identifierHash` is a different persisted instance.
- New required dependencies for hosts: `flutter_secure_storage`, `webview_flutter_android`; `flutter_chat_ui`/`flutter_chat_core` 2.x draws with `material_ui`.
- Minimum SDK: Dart `^3.13.0`, Flutter `>=3.47.0`.

### Added

- `chatwootSignOut(...)`: one call that clears the native client's persisted data and the webview session for a user.
- `ChatwootCallbacks.onConnectionStateChanged(ChatwootConnectionState)`, `ChatwootChatStyle` (`classic`), re-exported `Message` type.
- Realtime: ActionCable handshake with subscribe-on-welcome, 20 s presence, stale watchdog, exponential reconnect, latest-page refetch after a reconnect.

### Fixed

- `clearData`/`clearAllData` deleted nothing or threw `Box not found`; second `clearAllData` hit a disposed container.
- Recovery after 401/403/404 crashed on a null contact, wiped everything on any 404, and left the socket on the dead pubsub token.
- Typing/stopped-typing callbacks were swapped; typing never cleared; presence timer misbehaved; `isMine` counted activity messages.
- Duplicate messages from the server echo; stale messages sorted lexicographically; one malformed item blocked a whole list; huge numbers crashed parsing.
- Native chat crashed in apps that use `flutter/material` only; sends before the client was ready crashed; a late client leaked after dispose.
- Webview: script injection through user names, a stale `loaded` event stored the token under another user, cross-user conversation token reuse, setState after dispose.
- The published package lacked the generated `*.g.dart` files (they were gitignored); `.pubignore` now ships them.

### Security

- Data at rest is encrypted; secrets (`source_id`, `pubsub_token`, `identifierHash`) are not logged and not persisted in plaintext.
- https enforced by default; URL path parts are percent-encoded; navigation inside the webview is restricted to the widget page, other links open in the OS browser, dangerous schemes are blocked.
- The webview bridge only honours messages from the current widget page, once per load, with a JWT-shaped token; sign-out wipes cookies, storage and cache.
- Realtime events are accepted only for the stored conversation and cannot change a message's author or type.
- Strict analysis (`strict-casts`, `strict-inference`, `strict-raw-types`, flutter_lints, `unawaited_futures`, ...) is enforced in CI.
