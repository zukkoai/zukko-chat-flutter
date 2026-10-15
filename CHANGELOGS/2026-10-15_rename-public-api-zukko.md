# Rename public API and package to Zukko

## What
Package `chatwoot_sdk` is now `zukko_chat_flutter` (barrel `lib/zukko_chat_flutter.dart`); every exported `Chatwoot*` symbol is `ZukkoChat*`. README, CHANGELOG (0.1.0 "Renamed" section), `doc/` and `CLAUDE.md` use the new names.

## Why
Owner rule: everything a developer sees when the package is published or integrated must say Zukko, not Chatwoot.

## Public old -> new
| Old | New |
|---|---|
| `ChatwootClient` | `ZukkoChatClient` |
| `ChatwootChat` / `Options` / `Theme` / `Style` / `Interactions` | `ZukkoChat` / `ZukkoChatOptions` / `ZukkoChatTheme` / `ZukkoChatStyle` / `ZukkoChatInteractions` |
| `ChatwootClientException` / `ChatwootClientExceptionType` | `ZukkoChatException` / `ZukkoChatExceptionType` |
| `ChatwootCallbacks`, `ChatwootL10n` | `ZukkoChatCallbacks`, `ZukkoChatL10n` |
| `ChatwootClientFactory` | `ZukkoChatClientFactory` |
| `ChatwootUser`, `ChatwootMessage`, `ChatwootUpload`, `ChatwootContact`, `ChatwootConversation`, `ChatwootEventMessageUser` | `ZukkoChat*` equivalents |
| `ChatwootChatView`, `ChatwootChatController`, `ChatwootChatStatus` | `ZukkoChatView`, `ZukkoChatController`, `ZukkoChatStatus` |
| `ChatwootConnectionState`, `ChatwootActionType` | `ZukkoChatConnectionState`, `ZukkoChatActionType` |
| `chatwootSignOut` | `zukkoChatSignOut` |

## Unchanged (internal)
`src/` file names (`chatwoot_*.dart`), internal classes (`ChatwootRepository`, `ChatwootSocket`, `ChatwootClientService`, `ChatwootMessagesDao`, `ChatwootBoxNames`, `ChatwootKeyStore`), Hive box names and secure-storage key strings (on-device data stays readable), `LICENSE` (upstream MIT notice). Older CHANGELOG entries are untouched.
