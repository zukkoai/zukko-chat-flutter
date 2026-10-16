# Review fixes: chat styles (S1-S23, U16, U24, X12, X13)

## What
- Shared message builders: `components/message_spec.dart` (`MessageStyleSpec`: values + the style's own `wrap`), `message_content.dart` (text, image, gallery, file, audio widgets, `MediaWithCaption`), `styles/shared/message_builders.dart`. Each style now only supplies a `*_message_spec.dart`.
- `ChatBaseTokens` + `ZukkoChatTheme.pick/tone/accentOr/onAccentOr/font`: token scaffolding written once; `*_tokens.dart` hold the palette only. Metrics moved to `*_metrics.dart`.
- `BaseChatStyle` (getters, cached `chatTheme`, footer, builders); shared `ChatHeaderBar`, `TypingIndicatorRow`, `composer_parts.dart` (input, send, attach, mic), `message_chrome.dart` (`SendingOpacity`, `FailedHint`, `ChatBubble`).
- Tests: golden snapshots per style, light and dark (macOS only), and behaviour tests.

## Bug fixes (visible changes)
- S14 media width is clamped to the room (320 dp screens).
- S15 composer padding never negative.
- S16 derived colours follow accent / background overrides (defaults unchanged).
- S19 Minimal Clean shows the message time; attach is hidden while recording in all styles.
- S20 buttons are 48 dp (composer heights kept within a few px).
- S21 header title is a heading, failed hint is a live region, recording bar grows with text scale.
- U24 typing fires on text edits only, not caret moves.

## Not done here (other files)
- S22 caching `style.resolve` in the view, S13 `ChatMessageEnv.authorName` (contract / view are not in this scope).
