# Localization audit

## What
- New `ZukkoChatL10n.unsupportedMessageText`: a message kind the SDK cannot show used to render flutter_chat_ui's English "This message is not supported". The shared builders now set `unsupportedMessageBuilder`.
- New `ZukkoChatL10n.fileSizeUnits` (+ `sizeUnits`): file tiles showed `B/KB/MB/GB`; they now use the locale's units (`Б/КБ/МБ/ГБ` for ru and uz Cyrillic). `formatBytes` and `FileTile` take the units.
- Translation fixes: uz Cyrillic file-limit text had Latin `MB` (now `МБ`); Turkish "Görüşme" (conversation) is now "Sohbet", like the rest of the chat wording; the typing text uses `…` like the other texts, in all locales.

## Why
TODO #18: every text a chat user sees or hears must follow the host app's language (en, ru, uzLatn, uzCyrl, tr, kaa).

## Notes
- No date separators exist in the SDK; message times are `DateFormat.Hm()` (24 h `HH:mm`, the same in all six locales), so no `intl` locale data is needed. A host can still pass `ZukkoChatOptions.timeFormat`.
- `material_ui` localizations stay English-only, but nothing visible uses them (the message list has no tooltips, selection toolbars or dialogs). The composer's `TextField` uses the host's Flutter `MaterialLocalizations`.
- Public API is only extended (two optional constructor fields); host overrides keep working.

## Tests
`test/ui/l10n/zukko_chat_l10n_locales_test.dart`: `forLocale` mapping, non-empty fields, placeholders, no script mixing, no `...`, size units, and a pump of each chat style in each locale asserting no English UI string.
