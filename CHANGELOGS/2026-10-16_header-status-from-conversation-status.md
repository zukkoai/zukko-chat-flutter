# Header status from conversation status

## What
The chat header status is computed from the conversation status plus agent presence: `pending` / `resolved` / no conversation yet -> online; `open` / `snoozed` -> online only while an agent is online. Typing still overrides while it lasts.

## Why
The backend AI answers 24/7 while the conversation is `pending` (and reopens a `resolved` one as `pending`). The header showed "We're away" from agent presence alone, although the AI would reply.

## Fix
`ZukkoChatController._refreshStatus` combines the conversation status (initial `GET /conversations` via `onConversationUpdated`, then live `conversation.created/updated/status_changed`) with presence and typing. `onConversationIsOnline/Offline` keep meaning agent presence. The repository now also emits `onConversationUpdated` once after the initial conversation fetch.
