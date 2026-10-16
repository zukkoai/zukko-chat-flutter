# Review fixes: chat UI (controller, view, components, l10n)

## What
- Controller split: `ChatMessageMapper` (server message -> chat message, local previews), `ChatMessageStore` (key/echo aliasing, merge, one ordering for insert and bulk load, session reset), `OutgoingTyping` (typing debounce). The controller keeps lifecycle, outbox and callbacks.
- View split: `ChatHeader`/`ChatViewHeader`, `ChatMessageList`, `ChatErrorBanner`, `chat_attachment_flow.dart` (attach flow, voice issue text, notice). Style, theme, env, builders, material_ui theme and the default time format are resolved only when style/theme/strings/controller change, not on every build; the composer data survives rebuilds.
- Components: `attachment_preview.dart` -> `chat_image.dart`, `image_grid.dart`, `file_tile.dart`; `image_viewer.dart` -> `chat_image_tap.dart`, `image_viewer.dart`, `zoomable_image.dart` (no import cycle); `voice_recorder.dart` -> `voice_capture.dart`, `voice_recorder_controller.dart`, `voice_record_widgets.dart`; `audio_engine.dart` (player behind `AudioPlaybackController`). `components/components.dart` is the barrel styles import.
- `clientFactory` is now a normal documented public option of `ZukkoChat` (no `@visibleForTesting`): supply your own client, e.g. an offline demo or tests.

## Bugs fixed
- Late callbacks from the client replaced by `retry()` no longer re-set the error or touch the list (generation guard).
- One position tick of a playing voice message no longer rebuilds every voice bubble (per-message `watch`); a slow audio load can no longer overwrite a newer one.
- Images and avatars are decoded at their drawn size (`cacheWidth`/`cacheHeight`).
- Screen readers can record a voice message (tap action starts/sends); the recording bar is a live region.
- 48dp tap targets for the audio play button and the powered-by link.
- Reduce motion: typing dots stand still, image viewer route/spring/zoom do not animate.
- Double-tap zoom animation uses one listener; viewer uses the L10n index label, `AlignmentDirectional`, named constants and a `Material` instead of the decoration hack.
- `onConversationUpdated` is forwarded to the consumer (it was dropped).
- Typing dots use alpha instead of `Opacity` (no saveLayer per frame); placeholder waveforms are cached.
- Hidden message types use the model's `isActivity`/`isTemplate`.

## L10n
- New: `imageIndexLabel` (`{i}`/`{n}`), `voiceRecordingLabel`; `fileTooLargeText` uses `{maxMb}` filled from `ZukkoChatUpload.maxSizeMb`.
- `poweredByText` added for uzLatn, uzCyrl, tr, kaa (native-speaker review wanted). A test checks every language translates every string.

## Leftovers

- `components/components.dart` now also exports `message_chrome`, `message_content`, `message_spec`, `composer_parts`, `chat_header_bar`, `typing_indicator_row`; styles import the barrel only (redundant imports removed).
- S13: `ChatMessageEnv.authorName(userId, isSentByMe)` is filled by the view; the duplicate name logic in `styles/shared/message_builders.dart` is gone.
- S22: confirmed, the view already caches the resolved style/env/builders and recomputes only when style, theme, l10n, time format or controller change.
- Dead code sweep: nothing unreferenced found.
