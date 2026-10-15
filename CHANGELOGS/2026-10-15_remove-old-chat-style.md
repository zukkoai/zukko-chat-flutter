# Remove the old chat style

## What
- Deleted `classic_style.dart`, `chatwoot_chat_style.dart` and the style seam.
- Removed public API: `ChatwootChatStyle`, `ChatwootChatOptions.style`, `ChatwootChatOptions.showUserAvatars`, `ChatwootChatOptions.showUserNames`.
- The native chat now renders the flutter_chat_ui default look. Pagination (`onEndReached`, `onEndReachedThreshold`) is wired directly in `ChatwootChatView` through `chatAnimatedListBuilder`.
- Removed the failed-message semantics hint that lived in the old style.

## Why
Clean slate for new chat styles written from scratch (`styles/<name>/`, shared widgets in `components/`).
