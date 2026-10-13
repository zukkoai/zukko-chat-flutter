# Phase 2A: realtime socket, repository events, interceptor recovery

## What
- New `ChatwootSocket` (`lib/src/data/remote/realtime/chatwoot_socket.dart`) owns the whole ActionCable connection; `socket_frame.dart` holds the sealed `Frame` parser. `ChatwootClientService` is REST only (no `connection`, no socket methods). `ChatwootRepositoryImpl` takes the socket by constructor and only maps `SocketEvent`s to callbacks.
- Interceptor recovery moved from the dead `onResponse` to `onError`.
- `ChatwootEvent` / `ChatwootEventType` / `ChatwootAction` / `ChatwootActionData` classes removed (inbound frames are parsed by `Frame`, outbound frames are built by the socket). Enums map to wire names through one `wire` field.
- Public API additions: `ChatwootCallbacks.onConnectionStateChanged(ChatwootConnectionState)`, enum `ChatwootConnectionState`, error types `SOCKET_SUBSCRIPTION_REJECTED`, `SOCKET_DISCONNECTED`. Existing callbacks unchanged.
- `ChatwootClientServiceImpl({required Dio dio})` (no baseUrl; internal).

## Symptom / Root cause / Fix per group (ids from review-socket-remote.md)

**No lifecycle (S1, S2, S8, S17)**
- Symptom: after a server close, network drop or sleep realtime was dead until restart; `sendMessage` before the subscription confirmation opened a second socket (double events, leaked channel); `dispose()` left the socket open (contact stayed "online"); typing/presence silently lost when not connected, `StateError` on a closed sink.
- Root cause: `stream.listen` without `onDone`/`onError`; the socket was a public mutable field on the REST service; `listenForEvents` was re-entered from `sendMessage`; dispose only cancelled subscriptions.
- Fix: `ChatwootSocket` state machine (idle/connecting/connected/subscribed/backoff/closed), idempotent `connect()` that tears the old channel down first (sink `close(1000)`), reconnect with `min(30 s, 1 s*2^n)` + up to 25 % jitter (reset on a confirmed subscription), one `_teardown()` for channel, subscription and all timers, `dispose()` closes the sink and ignores late frames, `send()` returns `false` instead of throwing. Repository `dispose()` order: socket, then storage. `sendMessage` no longer starts the socket.

**Handshake and frames (S3, S5, S16, S23)**
- Symptom: a non-JSON/binary/odd frame threw inside the listener (unhandled error, no `onError`); `reject_subscription` and `disconnect` were silently "unknown event"; `http`-in-host and trailing-slash URLs; `eventTypeToJson` produced `"ChatwootEventType.welcome"`.
- Fix: `Frame.parse` returns a sealed `Frame` and never throws (anything malformed is `UnknownFrame`). Subscribe is sent on `welcome`. `reject_subscription` -> `SocketFailure(SOCKET_SUBSCRIPTION_REJECTED)`, channel closed, no blind retry, no presence. `disconnect{reconnect:false}` -> `SOCKET_DISCONNECTED`, stop; `reconnect:true` -> backoff. URL built with `Uri` (`chatwootCableUri`: `ws`/`wss`, keeps port and path prefix, no `//cable`). Dead `ChatwootEvent` serializers removed.
- Stale watchdog: a one-shot timer re-armed on every frame (6 s; 15 s for the first frame after connecting) treats a silent half-open connection as lost.

**Event handling (S4, S6, S12, S13, S14, S15)**
- S4/S6: `echoId!`, `message!.data!`, `users as Map` crashed on frames from other devices or malformed events. Now: a frame without data is ignored, `users` must be a `Map`, an own message without `echo_id` is `onMessageReceived`, a throwing callback does not stop later events.
- S12: typing never cleared. Now a 30 s one-shot timer (restarted by every `typing_on`, cancelled by `typing_off`, an agent message, resolve or a lost connection); `is_private` typing is ignored (new `is_private` field on the event data).
- S13: presence used a periodic timer as one-shot and never reported an empty agent list. Now `Timer(40 s)` restarted per update, empty/no-online users are offline immediately, timer cancelled when the connection is lost.
- S14: `isMine` was `messageType != 1` (activity/template counted as mine). Now `== 0`; activity (2) and private messages are skipped in the handler; template (3) is received.
- S15: `print` of whole frames removed from the repository in phase 1; a test now guards message content never reaching `print`.
- Added: duplicate agent frames (same message id already stored) are not reported twice.

**Reconnect refetch (S11)**
- On a re-subscription (`isReconnect`) the repository fetches the latest messages page (`getAllMessages`) and merges by id (storage is keyed by id; the UI also merges by id). The public API only supports `before` paging, so "everything after the last id" is not available; the latest page is the best effort until the Widget API (`after`) lands. Failure goes to `onError`.

**Send failures (S18)**
- Any error from `createMessage` (FormatException, TypeError, ...) is wrapped into a `ChatwootClientException(SEND_MESSAGE_FAILED, data: echoId)`; a failing local save after a successful send no longer turns the send into an error.

**Interceptor (S9, S10, S19)**
- Symptom: 401/403/404 never recovered (Dio routes 4xx to `onError`, the recovery lived in `onResponse`); N parallel failures would each recreate; the recovery kept the rejected contact.
- Fix: `onError` handles 401/403/404: under the single lock, if the request was issued in the current generation the session (contact + conversation + messages) is cleared and recreated (the stored user is kept and sent again), otherwise it only replays on the already new session. Replay once (`extra['retried']`), a second failure rejects. No `!`. `_ensureSession()` is shared by bootstrap and recovery. Path templates are built by `ChatwootPaths` (service and auth service share them).

**Other**
- Presence/`update_presence` `data` is now a JSON *string* as the ActionCable `message` command requires (the nested object sent before is rejected by Rails' `ActiveSupport::JSON.decode(data["data"])`). Not verifiable without the server; flagged for the integration phase.

## Tests (all fake_async + `FakeChannel`, real Dio on a scripted adapter)
- `test/data/remote/realtime/chatwoot_socket_test.dart` (31): handshake, presence at t=0/20/40/60 and no stacking, backoff doubling/reset/cap, stale watchdog, connect timeout, idempotent connect, reject, disconnect, garbage frames (zone-guarded, 0 uncaught), send while disconnected / closed sink, dispose, URL building.
- `test/data/chatwoot_repository_realtime_test.dart`: idempotent listen, echo/no-echo/duplicate/activity/private/template messages, malformed frames, reject -> onError, refetch exactly once per reconnect, connection-state callback, typing (30 s, off, restart, private, agent message, connection loss), presence (40 s, restart, empty, not online, cancelled on drop), resolve, sendAction, dispose (late frames, timers), no printing.
- `test/data/chatwoot_repository_test.dart`: send failures carry the echo id for FormatException/StateError/TypeError.
- `test/data/remote/api/chatwoot_client_api_interceptor_test.dart`: 401/403/404 -> one new session + one replay, user survives, concurrent failures -> one session, second 404 rejects, recreation failure typed, 500 untouched.
- `test/data/models/chatwoot_models_test.dart`: `isMine` table, wire-name round trips, `is_private`. `test/public_api_test.dart`: new exports.
- Mutation checks (change made, tests must fail, then restored): presence 20->30 s, connect without teardown, unguarded parse, no generation check, `isMine != 1`, no refetch, no typing timer, dispose skipping the socket, presence timer kept on drop, no stale watchdog, blind retry on reject, private typing not ignored, `echoId!`, send catching only `ChatwootClientException`, empty users not offline, backoff not reset, dispose without sink close, naive cable URL. All killed.

## Not fixed here
- Token refresh via `/config` after a rejected subscription (the SDK has no `/config` call until the Widget API migration); the reject is reported through `onError` and the socket stays closed until `connect()` is called again.
- `conversation.created/updated`, `contact.merged` events (no callbacks for them yet).
- `GET /messages?after=<id>` (needs the Widget API).
