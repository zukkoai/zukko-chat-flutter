# Widget API migration

## What
The SDK moved from the Chatwoot Public Client API (`/public/api/v1/inboxes/...`, API inbox, `inboxIdentifier`) to the Zukko chat server's Widget API (`/api/v1/widget/...`, Website inbox, `websiteToken`).
- Session: `WidgetSession` (`/config` with the saved JWT, `PATCH /contact/set_user`, second `/config` on a token swap, `GET /contact` check, stored contact mirrors the identity), `WidgetAuthInterceptor` (`website_token` + `X-Auth-Token`, 404 revalidation and replay), `WidgetConfig`.
- REST: messages with `before`/`after`, `GET /conversations` (one object), message send as JSON or multipart `message[attachments][]`, `toggle_typing`, `update_last_seen`.
- Realtime: `conversation.created/updated/status_changed`, agent attachments, `after=` refetch after a reconnect, rejected / silent subscription refreshes the session once before giving up.
- UI: typing with a 3 s idle debounce, `markSeen` on open and on incoming messages while visible, banners for `INVALID_IDENTIFIER_HASH` / `SESSION_EXPIRED` (new l10n strings in all 6 languages), the message list is cleared on a session reset.
- New public API: `websiteToken`, `ChatwootClient.config/setTyping/markSeen`, `sendMessage(replyTo:)`, callbacks `onConversationUpdated` and `onSessionReset`, exception types `SESSION_EXPIRED`, `INVALID_IDENTIFIER_HASH`, `IDENTIFY_FAILED`, `GET_CONFIG_FAILED`.

## Why
The Zukko server exposes the web widget contract only; the SDK has to use the same identity (HMAC `identifier_hash`), session (JWT) and realtime (`pubsub_token`) rules as the web widget.

## Decisions
- HMAC 401 fails closed: no anonymous fallback, no fetch, no socket; the UI shows a banner without a retry button.
- A resolved conversation is not wiped any more (as in the web widget): the status is stored, `onConversationResolved` fires once, the user may keep writing.
- Typing and seen ship in v1. CSAT, pre-chat form, working hours and `toggle_status` do not.
- Attachments are multipart only (the server derives `file_type` for uploaded files); direct upload is not used.
- `contact.merged` is broadcast to agents only, so it is not implemented.
- The JWT lives in the encrypted contact box (`ChatwootContact.authToken`, `@HiveField(5)`), never in JSON or logs. Hive field and type ids were not renumbered; the instance key changed (`websiteToken`), so Public-API data is simply not reused.
- A rejected subscription refreshes the session at most 3 times per minute (shared budget with 404 recovery); an unchanged pubsub token leaves the socket closed and reports `SOCKET_SUBSCRIPTION_REJECTED`.

## Deleted
`chatwoot_client_auth_service.dart`, `chatwoot_client_api_interceptor.dart` (placeholders, lazy contact/conversation creation, 401/403/404 matrix) and their tests; all `/public/api` paths; `inboxIdentifier`, `source_id` semantics, `getConversations()`; exception types `CREATE_CONTACT_FAILED`, `CREATE_CONVERSATION_FAILED`, `GET_CONTACT_FAILED`, `UPDATE_MESSAGE_FAILED`.

## Open
Live-server checks (dead pubsub token, `set_user` merge) are in `TODO.md`.

## Review fixes
1. Controller: a failed send marks its bubble for ANY typed error whose `data` is an echoId in the outbox (was SEND_MESSAGE_FAILED only).
2. `WidgetSession.onReady` / first-start reset: a start that succeeds after an initial failure, or adopts another contact, brings the socket up (`repository.onSessionReady`, `onSessionReset`); `initialize` no longer connects with an unusable session.
3. Reconnect cursor (`_cursor`) comes from fetches and socket events only, never from our own REST send ids.
4. The first subscription also refetches (`after=cursor`, or the latest page).
5. A rejected subscription with an unchanged token retries after 60 s, 120 s ... 10 min (once reported); `ChatwootClient.resume()` retries at once; the controller calls it on app resume; stops on dispose / fail-closed.
6. Half-failed rebuild: the generation bump + `onSessionReset` happen in a `finally` when the stored contact changed; `widget_auth_token` is only passed to the follow-up `/config`; a failing `GET /contact` check is an identify failure.
7. `chatwootDio`: no redirects, 15 s / 30 s / 60 s timeouts on both Dios.
8. `set_user` fails closed for identified users (`IDENTIFY_FAILED`, retryable; 401 stays terminal); banner shows retry.
9. `start()` backs off (2 s ... 60 s) after failures and each rebuild has a 90 s backstop timeout, so the lock cannot be held forever.
10. New warning type `IDENTITY_NOT_VERIFIED` (identifier without hash); README: "Enforce identity validation" is required.
11. `validateUploadFile` stats path uploads of unknown size; the web picker checks the size before `readAsBytes()`.
12. `after` paging stops after 20 pages (verified against `message_finder.rb`: `id > after`, `limit(100)`); `_known` capped at 2000. Persisted per-conversation cap: TODO.
13. `ChatwootUser.toString` shows no identity data.
14. `LocalStorage.clearInstanceFamily`: sign-out removes records of the identifier under every hash digest.
15. `markSeen` throttled (1 per 2 s + trailing); `ChatwootSocket.connect()` is a no-op for a live connection with the same token; presence every 15 s; same-contact 404 probes cost no recovery budget (failing probes and real rebuilds still do).

Tests: `test/data/remote/api/widget_session_hardening_test.dart`, `test/data/chatwoot_repository_hardening_test.dart`, `test/ui/chat/chatwoot_chat_controller_hardening_test.dart`, `test/chatwoot_sign_out_rotated_hash_test.dart`, helper `test/utils/scripted_widget.dart`. Existing tests adapted where behaviour changed (first-subscription refetch, 15 s presence, set_user fail-closed, idempotent connect).

## Test hardening
- `crypto` is now a dev dependency (3.0.7) instead of an ignored transitive import in `test/utils/fake_chat_server.dart`.
- `ChatwootClient.create` got a `@visibleForTesting socketSubscribeTimeout`; the "unknown pubsub token" e2e test uses 200 ms (was ~21 s real time; the file runs in ~12 s, the rest is the 6 s stale-watchdog test).
- Every review fix (1, 2, 4, 5, 6, 8-15) was mutation-checked: the fix was broken in `lib`, the covering tests failed, the code was restored. The only vacuous one was the `_known` 2000 cap (12): new test "the in-memory message index is capped at 2000" in `test/data/chatwoot_repository_hardening_test.dart`.
