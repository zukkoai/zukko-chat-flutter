# Internal rename to zukko_chat and shared helpers

## What
- Every remaining `chatwoot_*` file and `Chatwoot*`/`chatwoot*` identifier in `lib/`, `test/` is now `zukko_chat_*` / `ZukkoChat*` / `zukkoChat*` (doubles collapsed, e.g. `chatwoot_chat_controller.dart` -> `zukko_chat_controller.dart`). Files moved with `git mv`; `*.g.dart` regenerated. Internal id strings `chatwoot-` -> `zukko-`.
- Unchanged on purpose: Hive box name string values (`ChatwootContactBoxNames.CONTACTS.enc` ...), secure-storage key `chatwoot_sdk_hive_key`, Hive typeIds and field indices, wire protocol.
- Duplicated logic collapsed into single helpers (below). `ZukkoChatClient.create` no longer aborts when a host `onError` throws.

## Why
Owner wanted no Chatwoot naming left in the code; the code review found the same snippets copy-pasted in several places.

## Renames (examples; same rule for every file)
| Old | New |
|---|---|
| `chatwoot_client.dart` / `chatwoot_sign_out.dart` | `zukko_chat_client.dart` / `zukko_chat_sign_out.dart` |
| `chatwoot_chat_controller.dart` (+ view/page/options/style/theme) | `zukko_chat_controller.dart` (+ ...) |
| `ChatwootRepository(Impl)` | `ZukkoChatRepository(Impl)` |
| `ChatwootSocket`, `ChatwootClientService(Impl)` | `ZukkoChatSocket`, `ZukkoChatClientService(Impl)` |
| `ChatwootMessagesDao` (+ InMemory/Persisted) | `ZukkoChatMessagesDao` |
| `ChatwootBoxNames`, `ChatwootKeyStore` | `ZukkoChatBoxNames`, `ZukkoChatKeyStore` |
| `chatwootInstanceKey`, `chatwootDio`, `registerChatwootAdapters` | `zukkoChatInstanceKey`, `zukkoChatDio`, `registerZukkoChatAdapters` |
| `chatwoot_message.dart` etc. (models, events, paths, request) | `zukko_chat_message.dart` etc. |

## Shared helpers (`lib/src/shared/`)
- `url_policy.dart`: `isHttpUrl`, `isHttpsUrl` (case-insensitive scheme).
- `backoff.dart`: `exponentialBackoff` (socket reconnect, session start retry, rejected-subscription retry).
- `safe_invoke.dart`: `safeInvoke` (repository `onError`, session callbacks, `create`).
- `format.dart`: `formatDuration`, `formatBytes`. `wav.dart`: `wavFromPcm16`.
- `ZukkoChatUpload.maxSizeMb` / `maxSize` is the one upload limit; `ZukkoChatPaths.websiteTokenParam` / `authTokenHeader` hold the wire names.
