# Review fixes: core / data / shared

## What
- **Repository split.** `ZukkoChatRepositoryImpl` (init, send, clear, dispose) now delegates to `MessageSync` (message cache, cursor, paging, persisting), `RealtimeEvents` (socket event routing, typing / presence timers) and `SubscriptionRecovery` (rejected-subscription recovery and slow retry). `ZukkoChatRepository` is an interface; `markSeen` uses the new `TrailingThrottle`.
- **Session split.** `WidgetSession` keeps the lock / state machine; HTTP lives in `WidgetSessionApi` (`config`, `setUser`, `currentContactId`), the rebuild budget in `RateBudget`. `config` and `generation` are read-only; "session replaced" (generation++ and reset callback) has one owner (`_markReplaced`). The repository registers itself via `session.listener` (no `late final` forward reference in the composition root).
- **Storage split.** `HiveDatabase` (init, adapters, cipher, open / wipe), `ZukkoChatBoxNames` file, `LocalStorage` (3 stores, `persisted` / `inMemory` / `clear`), `openStorage` (open with in-memory fallback, reports `STORAGE_FAILED`).
- **Socket / client.** Event types in `zukko_chat_socket_events.dart`, `ZukkoChatConnectionState` in `core/`, cable URL in `url_policy.dart`, `defaultSocketBackoff` in `backoff.dart`. `ZukkoChatClient.create` wiring moved to `wireZukkoChat` (`core/zukko_chat_client_factory.dart`).
- **Deleted:** the legacy 0.0.9 / plaintext-box migration (code, `legacy*` box names, `zukkoChatInstanceKeyFromLegacy`, tests) and the dead user store (`HiveUserStore`, `toPersistable`, user box writes, `initialize(user)`). Hive type id 3 and the users box name stay reserved; a full wipe deletes the old users box.
- **Public API.** `ZukkoChatConfig` (was `WidgetConfig`, now `data/models`) and `ZukkoChatConversation` are exported with full dartdoc; `ZukkoChatConversation` lost the never-filled `messages` / `contact` (Hive fields 2, 3 retired), gained `isResolved`, `statusResolved`, `copyWith`. `ZukkoChatException` has optional `error` / `stackTrace`. `ZukkoChatClient` no longer exposes `callbacks`, `user`, `baseUrl`, `websiteToken`. `ZukkoChatMessage` gained `typeFromContact/typeFromAgent/typeActivity/typeTemplate`, `isActivity`, `isTemplate`.
- **Helpers added** in `shared/`: `RateBudget`, `TrailingThrottle`, `bestEffort`, `safeAvatarUrl`, `compareByTimeThenId` (in `data/models/message_order.dart`; `shared/message_order.dart` is a re-export shim until the UI imports the new path).
- Upload rules moved to `core/zukko_chat_upload_policy.dart` (`validateUpload`, async, one size message from `ZukkoChatUpload.maxSizeMb`); `message_body.dart` only builds bodies. Uploads get their own 5 min send timeout.

## Bugs fixed (each with a test)
- B1 the trimmed base url is used for Dio, the cable url and the storage key (also in `clearData`); user info / fragment in the url are rejected.
- B3 / D8 an event with a string / float id (or a malformed sender / attachments) no longer drops the whole event; the event payload keeps the raw map and reads it through `intFromJson`.
- B5 an own message without `echo_id` (sent from another device) is no longer reported as "received".
- D6 `typing_off` without `typing_on` no longer fires `onConversationStoppedTyping`.
- B6 one owner for "session replaced"; an unchanged rebuild is not a reset.
- R6 a synchronous throw while persisting is logged, not turned into a failed fetch.
- R11 a Hive box that had to be recreated (lost key) is reported once as `STORAGE_FAILED`.
- R10 at most 500 messages are kept per instance.
- Logs / messages carry only `runtimeType` / status, never `$e` (R12); swallowed errors are logged (R4).

## Why
Owner code review of the data layer: duplicates, bugs, SRP and misplaced code, dead code.

## Not changed on purpose
Hive box name strings, the secure-storage key `chatwoot_sdk_hive_key`, Hive type ids and field indices, the wire protocol.
Left for later: `ZukkoChatNewMessageRequest` stays a class (M6), `_registered` adapter set (M11), cancel token on session step timeout (R8), schema-version marker (R10), `createdAt` as `DateTime` and typed attachments (public API).
