# Phase 1: restructure into `lib/src`, generic storage, Riverpod removal

## What
- All code moved under `lib/src/{core,data,shared,ui}` (git renames); `lib/chatwoot_sdk.dart` is an exports-only barrel. Tests mirror the layout.
- One Dio call/error-mapping helper (`data/remote/api/api_call.dart`) replaces 8 copy-pasted try/catch blocks; dead `isBetween` removed.
- `shared/json_converters.dart` (null-tolerant), `shared/sdk_log.dart` (debug-only; every `print` removed from `lib/`).
- Hive: `hive_type_ids.dart` + `hive_adapters.dart` (single registration). Box names pinned as string literals (`ChatwootBoxNames`) so no user data is orphaned.
- Three duplicated single-value DAOs (contact/conversation/user, persisted + in-memory) replaced by `SingleStore<T>` (`HiveSingleStore`, `MemorySingleStore`). `LocalStorage.persisted(key)` / `LocalStorage.inMemory()` factories; `LocalStorage` fields are now `contact`, `conversation`, `user`, `messages`.
- Riverpod removed: constructor injection in `ChatwootClient.create`, `@visibleForTesting ChatwootClient.withRepository`, idempotent `Future<void> dispose()` that closes both Dios. `di/modules.dart`, `repository_parameters.dart`, `chatwoot_parameters.dart`, `providerContainerMap` deleted.
- Public API: `ChatwootActionType`, `ChatwootEventMessageUser`, `ChatwootChatTheme`, `ChatwootL10n` exported; `ChatwootCallbacks` fields are `final`; no barrel self-imports; dartdoc refs to internal types turned into prose.
- Deps: removed `riverpod`, `stream_channel`, `async`, and the now-unused dev dep `mockito`; added dev dep `fake_async`.

## Why / fixed bugs (ids from review-storage-di.md)

### Symptom / Root cause / Fix per group

**clearData / clearAllData broken (P1, P2, P3)**
- P1 `clearData` deleted nothing: it built the storage with instance key `""`. Fix: uses the real key. Test: `core/chatwoot_client_test.dart` "clearData clears the target instance and only that one".
- P2 `clearData`/`clearAllData` threw "Box not found" before any client was created. Fix: they open the DB first. Tests: "...works before any box is open (fresh process)" (x2).
- P3 second `clearAllData()` hit a disposed container. Fix: container map removed. Test: "clearAllData can be called twice".

**Lifecycle (P4, P5, P14, P15)**
- P4 static `providerContainerMap` shared by key: one client's `dispose()` broke the other, double dispose threw. Fix: each client owns repository + storage; `dispose()` idempotent. Tests: "dispose is idempotent", "two clients with the same key are independent...", "dispose can be called repeatedly".
- P5 init errors were lost or became uncaught async errors; `getConversation()!` crashed. Fix: `create()` awaits `initialize`, which routes every failure to `onError` and never throws; saves are awaited. Tests: `chatwoot_repository_test.dart` "no conversation after refresh...", "an unexpected error is wrapped...", `chatwoot_client_test.dart` "init failure is delivered to onError ... no uncaught error", "unreachable server".
- P14 `LocalStorage.dispose` was un-awaited/untyped, persisted `onDispose` empty. Fix: `Future<void> dispose()`, empty hook removed, boxes deliberately stay open for the process lifetime (documented). Test: "dispose stops event delivery and can be called twice".
- P15 `loadMessages`/`dispose`/`clearClientData` returned `void`/dynamic. Fix: all `Future<void>`. Test: "loadMessages ... awaitable".

**Keys / isolation (P9, P10, P11)**
- P9 messages and conversations were keyed by server id globally, so two instances overwrote each other. Fix: every record is keyed by the instance key (messages `<instanceKey>|m|<id>`); old layout migrated on `openDB` (see below). Tests: `local_storage_test.dart` "instances are isolated from each other" (both stores), "instance keys that are prefixes do not leak messages", migration test.
- P10 null user identifier was stored as "null" and collided with a real "null" user; `|||` in a component forged keys. Fix: null is an empty segment, `%` and `|` are escaped in components. Tests: `chatwootInstanceKey` group, "a user without identifier can be saved", "clearData for a user-less instance".
- P11 `contactIdentifier!` null checks. Fix: contacts are stored by instance key (no dependency on `source_id`); the interceptor rejects a contact without `source_id` with a typed `ChatwootClientException`. Tests: interceptor "a contact without source_id fails with a typed error", store "a contact without source_id can be stored".

**Parsing (P6)**
- P6 anonymous contacts (null name/email) and messages with null `message_type`/`conversation_id`/`created_at` crashed `fromJson`. Fix: nullable fields + null-tolerant converters. Tests: `data/models/chatwoot_models_test.dart`.

**Order / writes (P8, P9 part, P20)**
- P8 persisted messages were newest-first, in-memory oldest-first. Fix: one documented order (oldest first, ties by id) for both. Test: the same suite runs against both implementations.
- Messages are saved with one `putAll` (was 2N awaited writes), `print("saved")` removed, async-forEach in the in-memory DAO removed.
- P20 `box.values.length == 0` prechecks removed with the old DAOs.

**Public API / deps (P16, P17)**
- P16 `riverpod` hard constraint dropped (+ unused `stream_channel`, `async`). Test: `public_api_test.dart` pubspec check.
- P17 missing exports added, internals no longer leak. Test: `public_api_test.dart` imports only the barrel.

### Data migration (P9/P12-adjacent)
Layout before: value box keyed by entity id + an index box `instanceKey -> id`. Now: value box keyed by instance key; index boxes are read once by `LocalStorage.openDB()`, moved, and deleted from disk. Legacy instance keys `base|||null|||inbox` are translated to the new key format (a legacy key that does not split into 3 parts is left behind, harmless). Test: "migration of the pre-0.0.10 box layout".

## Structure
```
lib/chatwoot_sdk.dart            exports only
lib/src/core/                    chatwoot_client, chatwoot_callbacks, chatwoot_client_exception
lib/src/data/                    chatwoot_repository
  models/                        contact, conversation, message, user (Hive + JSON)
  remote/api/                    api_call, interceptor, auth service, REST service, requests/
  remote/realtime/               chatwoot_event, chatwoot_action, chatwoot_action_data
  local/                         local_storage, hive_type_ids, hive_adapters, instance_key, dao/{single_store,chatwoot_messages_dao}
lib/src/shared/                  json_converters, sdk_log
lib/src/ui/{chat,theme,l10n,webview}/
```

## Behaviour changes
- Non-persisted clients with the same key no longer share in-memory state (it was a side effect of the Riverpod container map). Persisted clients still share via Hive.
- `ChatwootClient.create()` now completes after the initial contact/conversation refresh (it returned immediately before). Refresh failures arrive through `onError`.
- Persisted messages are returned oldest first (were newest first).
- `LocalStorage.openDB({onInitializeHive})` hook removed; `LocalStorage.clearAll()` replaced by `LocalStorage.clearAllPersisted()`.
- `ChatwootCallbacks` fields are `final`.
- `ChatwootContact.name/email` are nullable.

## Not fixed here
P7 (createdAt as String), P12 (Hive typeId collision with host apps / own directory), P13 (encryption at rest), P18 (analysis_options), P19 remainder, P21; see TODO notes in the phase report. `ChatwootChatOptions` left to phase 2 (touches UI logic).
