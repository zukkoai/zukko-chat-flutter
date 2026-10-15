# Chat styles: Smooth Silk, Minimal Clean, Thread Feed

## What
- `ChatwootChatOptions.style` (`ChatwootChatStyle.smoothSilk` default, `minimalClean`, `threadFeed`), each with light and dark.
- Style contract `ChatStyle` in `ui/chat/chatwoot_chat_style.dart`; implementations in `ui/chat/styles/<name>/` (`*_style.dart`, `*_tokens.dart`, `widgets/`).
- Shared components in `ui/chat/components/`: composer shell (text + send + hold-to-record), voice recorder (hold, timer, slide to cancel, min/max length), audio player bar with waveform, image / image grid (`+N`), file tile, link preview card, linkified text (tappable http(s) links via url_launcher), typing indicator, avatar, "Powered by zukko.ai" footer, icon button.
- `ChatwootChatTheme` rewritten as the style-independent base: brightness, font, optional accent / background overrides; derived from the app `ThemeData` when not given.
- The controller maps https attachments to image, gallery (several images, `CustomMessage`), audio and file messages; others keep the attachment label.
- Header drawn by the style (page: back button when the route can pop, `title`; dialog: close button); `appBar` still replaces it.
- `ChatwootChatInteractions`: `onAttachmentPressed`, `voiceRecording` (`ChatwootVoiceRecordCallbacks`), `onMorePressed`; the buttons are hidden without them.
- `ChatwootL10n`: new strings and built-in translations `ru`, `uzLatn`, `uzCyrl`, `tr`, `kaa`; `ChatwootL10n.forLocale`; `options.l10n` now nullable (null follows the locale). `poweredByText` is now the prefix ("Powered by").

## Removed
- Old theme fields (`primaryColor`, `secondaryColor`, bubble/input radii, text styles, avatar colors, `toChatTheme`, `avatarColorFor`), the dialog's own header, the Chatwoot logo footer.

## Not verified
- Written without a Flutter SDK at hand: run `flutter analyze --fatal-infos` and `flutter test`.
