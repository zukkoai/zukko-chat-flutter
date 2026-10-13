# Phase 3A - data/core fixes from the final review and the security audit

Scope: `lib/src/data`, `lib/src/core`, `lib/src/shared`. The UI side is Phase 3B.

Id legend (the review files are not in the repo): `F<n>` = finding of the final
code review, `SEC<n>` = finding of the security audit.

## Storage: encryption, migration, adapters (SEC3, F2, F8, F9, F20, SEC5)

**Symptom**
- `source_id` (bearer credential), `pubsub_token`, e-mail, name, `identifierHash` and the
  full history sat in plaintext Hive files (backup, adb, rooted device) (SEC3).
- The migration deleted index entries / values it could not move: silent data loss (F2).
- A host app that registered its own Hive adapter on typeIds 0-4 made the SDK read its
  records with a foreign adapter (F8).
- Two concurrent `create()` calls both ran the migration; one deleted the index box while
  the other opened it (F9).
- `create()` could throw when Hive / path_provider failed, contrary to the docs (F20).
- The same user identifier with another (forged) `identifierHash` reused the stored contact (SEC5).

**Root cause**
Plain boxes under pinned names, a migration that recorded keys before checking they were
moved, `isAdapterRegistered` used as "ours", an unserialised `openDB`, `openDB()` outside the
`try` in `create()`, an instance key without the hash.

**Fix**
- Boxes are `HiveAesCipher`-encrypted. The 256-bit key is generated once and stored via
  `ChatwootKeyStore` (`SecureChatwootKeyStore` = flutter_secure_storage, iOS
  `first_unlock_this_device`); `LocalStorage.keyStore` is the test seam. New box names end in
  `.enc`; the old names are `ChatwootBoxNames.legacy*`. A box the key no longer opens is
  recreated (it only caches server state).
- `ChatwootUser.identifierHash` / `customAttributes` are never written (`HiveUserStore` writes
  `toPersistable()`, keeps the full user in memory for contact creation).
- Migration (SEC3 + F2): legacy plaintext records are written to the encrypted box first, then
  deleted from the old one. Unattributable records (unparseable legacy key) and their index
  entries stay untouched, and so do the boxes holding them. Existing encrypted values are never
  overwritten by stale legacy ones. Legacy users are migrated without hash/attributes.
- `openDB` runs under a `Lock` (F9).
- `registerChatwootAdapters` tries to register and turns Hive's "already registered" error into
  `ChatwootClientException(STORAGE_FAILED)` (F8, new exception type).
- `create()` catches `openDB` failures: `onError(STORAGE_FAILED)` + in-memory fallback (F20).
- Instance key gets `|||h:<fnv1a64 hex>` when `identifierHash` is set; without a hash the key
  is unchanged, so existing data and the migration stay compatible (SEC5).

**Tests**: `test/data/local/local_storage_test.dart` (file bytes contain no secret, plaintext
control, key reuse/lost key, user not persisted, 5 migration cases incl. unparseable key kept,
concurrent `openDB`, hash keys), `hive_adapter_conflict_test.dart`, `chatwoot_client_test.dart`
(storage failure, hash).

## Session recovery and realtime (F3, F12, SEC8, F19, F14)

**Symptom**
- After a 401/403/404 recovery the socket kept the dead pubsub token: no realtime (F3).
- Any 404 (even a deleted message) wiped the conversation, the messages and the contact (F12).
- Any 401/403/404 on any request, any `message_created/updated` for any conversation, and an
  update that flips author or `messageType` were accepted (SEC8).
- Two identical `message.created` frames in one tick were both reported while the async Hive
  put was pending (F19).
- `sendAction` dropped the bool; `subscribe` was public but always refused (F14).

**Fix**
- `ChatwootSocket(tokenProvider:)` reads the token on every open; `connect()` has no argument;
  `reconnectIfTokenChanged()`; the interceptor's `onSessionReset` callback calls
  `repository.onSessionReset()` (F3).
- Interceptor: 401/403 or 404 on contact/conversations path -> contact + conversation reset;
  404 on a messages path -> conversation only; max 3 resets per minute (injectable clock) (F12, SEC8).
- Repository: `message_created/updated` must carry the stored conversation id and a positive id;
  an update may not change `messageType` or the sender id; `_known` (in-memory by id) drives
  duplicate detection and the author check (F19, SEC8).
- `ChatwootActionType.subscribe` removed; `sendAction` returns `bool` (`Future<bool>` on the
  client) (F14).

**Tests**: socket token provider (3), interceptor recovery scope / rate limit / `onSessionReset`,
repository conversation-id/author/session-reset/slow-DAO tests.

## Parsing, errors, ordering (F7, F11, SEC6, SEC9, F13)

**Symptom**: `created_at: 99999999999999999` -> `RangeError`, `1e999` -> `UnsupportedError`;
one bad item blocked a whole list; id-less messages collided on id 0; `getMessages` let
non-typed errors escape (also from the unawaited reconnect refetch); `created_at` as
`String.compareTo` ordered wrongly across formats and `"10" < "9"`; server ids went
unencoded into URL paths.

**Fix**
- Converters are bounds-checked (non-finite/out-of-range -> fallback); `created_at` is
  normalised to ISO-8601 UTC at parse time, old stored strings still parse (F11, SEC6).
- `parseList` / `parseMessages` skip bad items and ids <= 0, also inside conversations (SEC6).
- `apiCall` catches `Object` -> typed exception (SEC6).
- `getMessages` catches everything -> `onError`; persist failures are only logged; guarded
  `onError`; the reconnect refetch has a `catchError` (F7, SEC6).
- One `sortMessagesOldestFirst` (`lib/src/shared/message_order.dart`): by instant, numeric id tie-break;
  used by both DAOs. The UI controller should switch to it (F11).
- Path segments are `Uri.encodeComponent`ed; a `source_id` that is empty, > 256 chars, `.` or `..` is
  rejected with a typed error (SEC9).
- `ChatwootClientException` fields are `final` (F13).

**Tests**: `test/shared/*`, `chatwoot_client_service_test.dart`, `api_call_test.dart`, repository tests.

## Base URL policy (SEC4)

`validateBaseUrl(url, {allowInsecure})` in `lib/src/shared/url_policy.dart`: https, or http only for
`localhost` / `127.0.0.1` / `::1` / `10.0.2.2` / `allowInsecure`. `ChatwootClient.create` calls it
(new `allowInsecure` parameter, default false; invalid -> `ArgumentError`), `chatwootCableUri` throws
for schemes other than http(s)/ws(s). Tests: `test/shared/url_policy_test.dart`, client and socket tests.

## Cleanup (F15, dead code, tests)

- `ChatwootEventMessageUser` moved to `data/models/chatwoot_event_message_user.dart` (same typeId 4,
  same fields); `models/` no longer imports `remote/` (F15).
- Removed `ChatwootClientService.updateContact/updateMessage` and `ChatwootMessagesDao.deleteMessage`
  (tests only). `withRepository` was already `@visibleForTesting`.
- `ChatwootClient.getClientInstanceKey` / `clearData` take `identifierHash`.
- `public_api_test.dart`: the field-reading and pubspec-grep tests are gone; replaced by checks of
  what the barrel exposes and of `create()` refusing insecure URLs.
- `HiveTestEnv` uses a fake key store and wipes the temp dir after each test.
