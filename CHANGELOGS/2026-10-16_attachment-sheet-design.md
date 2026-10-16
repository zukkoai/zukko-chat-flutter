# Attachment sheet redesign (3 styles)

## What
The "+" attachment sheet (Photo / File) now follows the design mockup, per style: Smooth Silk (rounded sheet, two cards with icon disc, limit note, pill cancel), Minimal Clean (floating group with the limit in the title, two rows, separate cancel), Thread Feed (small-radius sheet, close button, two bordered tiles, limit note). Rise animation 500 ms. New l10n fields in all 6 locales: attachSheetTitle, attachSheetTitleWithLimitText, attachImageHint, attachImageHintLong, attachImageHintShort, attachFileHint, attachFileHintShort, attachLimitNoteText, cancelLabel, voiceSlideLeftToCancel, voiceRecordingButtonLabel.

## Why
The sheet was a generic Material ListTile list that ignored the style.

## Fix
One shared `AttachSheet` (components/attachment_sheet.dart) drawn from a per-style `AttachSheetSpec` exposed as `ChatStyle.attachSheet`. The limit comes from `ZukkoChatUpload.maxSizeMb`. Behaviour unchanged (image / file / null). Tests and light/dark goldens in test/ui/chat/components/.
