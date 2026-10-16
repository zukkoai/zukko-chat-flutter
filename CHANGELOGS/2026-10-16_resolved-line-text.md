# New text for the resolved conversation line

## What
`conversationResolvedMessage` (the local system line shown when the conversation is resolved) now reads "Conversation closed. You can write again anytime" and is translated in all six locales.

## Why
The old "Your ticket has been marked as resolved" sounded like a support ticket and did not say the user can continue writing.

## Fix
Updated the default and the ru, uzLatn, uzCyrl, tr and kaa strings in `lib/src/ui/l10n/zukko_chat_l10n.dart`. The field name is unchanged.
