# Hide the mic when audio is off; warn instead of sending over the server limits

## What
- `ZukkoChatConfig.audioMessagesEnabled` is read from `website_channel_config.audio_messaging_enabled`. Only an explicit `false` hides the mic (with `options.enableVoiceMessages` also required); missing or non-bool keeps it on, so old backends work. `enabled_features` is not used (the widget `/config` never lists `web_widget_audio_messaging` there). Backend line needed in `widget/configs/create.json.jbuilder`: `json.audio_messaging_enabled @web_widget.inbox.account.feature_enabled?('web_widget_audio_messaging')`.
- Limits live next to `ZukkoChatUpload.maxSizeMb`: `maxMessageLength` (150000 chars), `maxAttachments` (15), `acceptedDocumentTypes` plus any image/video/audio.
- Text over the limit: the send button is disabled and an auto-dismissing notice says so; shortening the text re-enables send. Nothing is cut.
- Picked files over 40 MB, of a type the server rejects, or beyond the 15th are not sent; a notice names the reason. The rest of the pick is sent.
- New strings in all six locales: `messageTooLongText`, `tooManyFilesText`, `fileTypeNotSupportedText`.

## Why
The admin can turn voice messages off for the inbox, and the server answers 422 for oversized text, files and unknown types, so the user only saw a failed message.

## Fix
`ComposerShell` owns the text limit (shared by the three styles via `ChatComposerData.onTooLong`). `screenAttachments` / `attachmentWarning` do the file checks in the attach flow. `ZukkoChatView` reads the config from the client its factory returns.
