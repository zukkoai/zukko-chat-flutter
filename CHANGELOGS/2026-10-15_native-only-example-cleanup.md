# Native chat only; example reduced to the styles demo

## What
- Removed the webview widget (`lib/src/ui/webview/`: `ChatwootWidget`, bridge, token store), its tests and the `webview_flutter*` dependencies.
- Removed `ChatwootChatDialog`, the view's `compact` mode, the close header action and `ChatwootL10n.closeLabel`. The header has an optional back button (`ChatHeaderData.onBack`).
- `chatwootSignOut` only clears the native client data.
- `example/`: opens straight on `StylesDemoScreen` (three tabs), `debugShowCheckedModeBanner: false`; removed the old home list, web widget page, file picker code, `image`/`image_picker`/`path_provider`/`cupertino_icons` dependencies and the iOS photo/camera usage strings.
- README, CLAUDE.md, TODO updated.

## Why
Owner decision: the SDK ships the native chat with our three styles only.
