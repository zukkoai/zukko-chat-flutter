# Example app rewritten as a teaching resource

## What
- `example/lib` is fully commented and ordered for a first-time integrator: `main.dart` (organisation map), `home_screen.dart` (style picker, dark switch, open chat, sign out), `live/live_config.dart` (dart-defines, identifier vs identifierHash), `live/live_chat_screen.dart` (every public parameter of `ZukkoChat`, `ZukkoChatOptions`, `ZukkoChatTheme`, `ZukkoChatCallbacks`, `ZukkoChatInteractions` with defaults), `live/not_configured_view.dart` (exact run command).
- Sign-out now removes the chat from the tree, waits one frame, then calls `zukkoChatSignOut`, then rebuilds with a fresh key.
- `example/README.md` explains how to run and where each value comes from.
- `intl` added to `example/pubspec.yaml` (already a dependency of the SDK) for `timeFormat`.
- Tests: home styles and dark switch, not-configured instructions, `LiveConfig` user building.

## Why
The old example was minimal and uncommented; it did not show the API surface or the sign-out order. Real server only, config via `--dart-define`.
