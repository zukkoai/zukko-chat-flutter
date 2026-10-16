# Auto-scroll to new messages after a small scroll up

## Symptom
Scrolled up even a little, the user sends a message; the reply arrives below the visible area and the list does not follow it.

## Root cause
flutter_chat_ui's `ChatAnimatedList` sets an internal `_userHasScrolled` flag on any upward drag and clears it only when the user themselves idles at the bottom. While set, incoming messages never auto-scroll (`_subsequentScrollToEnd`). There is no option to tune this (`scrollToBottomAppearanceThreshold` only affects the button). The typing indicator, a bottom sliver, was hidden the same way.

## Fix
`ChatMessageList` now owns the auto-scroll (library one switched off via `shouldScrollToEndWhenSendingMessage/AtBottom: false`): on each single `insert` it scrolls to the end when the message is the user's own, or when the list was within one viewport of the end; the typing indicator appearing follows the same rule. Far-up history readers are not moved; loading older pages (a bulk set) never scrolls. Shared by all three styles. Tests: `test/ui/chat/chat_autoscroll_test.dart`.
