# Lazy older-history paging

## What
- The chat opens with at most the latest 20 messages. Older ones load 20 at a
  time only when the user scrolls to the top (`GET /messages?before=<oldest id>`).
- New `ZukkoChatClient.loadOlderMessages({required int before})`, backed by
  `ZukkoChatRepository.getOlderMessages` and `MessageSync.fetchBefore`.
- `ZukkoChatController.loadOlder()` is wired to the list's `onEndReached` for
  all three styles; the host's `ZukkoChatInteractions.onEndReached` still runs
  after ours.

## Why
Conversations with 200-1000 messages made opening the chat slow, and most users
never scroll up.

## Fix
- `getPersistedMessages` reports only the newest 20 of the (up to 500) cached
  messages, so first paint renders at most 20.
- Paging is single-flight, stops when a page has fewer than 20 messages, and a
  failure keeps the list (the next scroll to the top retries).
- Older pages live in memory only and are not written to Hive, so they can never
  push the newest 500 cached messages out. The built-in flutter_chat_ui spinner
  shows while a page loads.
- Realtime events and the `after=` reconnect catch-up are unchanged; ids are
  deduplicated by the message store.
