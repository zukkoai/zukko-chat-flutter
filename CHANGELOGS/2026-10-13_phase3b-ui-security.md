# Phase 3B: UI / webview fixes from the final review and the security audit

Ids: **F** = final code review finding, **SEC** = security audit finding (specs were scratchpad files, not in the repo).

## Public API changes
- `ChatwootWidget`: new `allowInsecure` (default false). `clearStoredConversation` now also wipes the webview's cookies, local storage and cache, so it is the sign-out call.
- `ChatwootChatOptions`: new `allowInsecure`. New `ChatwootChatInteractions` (`onEndReached`, `onEndReachedThreshold`, `onMessageLongPress`, `onMessageTap`, `onSendPressed`) replaces those five loose params on `ChatwootChat`; `ChatwootChatDialog` (and `.show`) take it too.
- `ChatwootChat` / `ChatwootChatDialog.clientFactory` is `@visibleForTesting`; `ChatwootClientFactory` has `allowInsecure`.
- `ChatwootL10n`: new `connectionErrorText`, `retryLabel`.
- `flutter_chat_core`'s `Message` is re-exported (`show Message`), it appears in the interaction callbacks.

## Webview (F4, F16, SEC1, SEC2, SEC4, SEC5, SEC7, SEC10)
**F4 stale `loaded`** : the scope was read from the current widget, so a `loaded` from user A's webview after a switch to B was stored under B. Fix: every load captures `_Load(url, scope, controller)`; messages from a load that is not the current one are dropped. Tests: A->B, old `loaded` writes nothing; B's own `loaded` writes under B.
**SEC1 session leak** : logout / user switch only deleted the token; cookies, localStorage and cache survived. Fix: wipe (cookies, local storage, cache) before the new target loads and in `clearStoredConversation`. Tests: ordered log shows the wipe before `loadRequest`; no wipe on first load or on a locale change; static clear wipes.
**SEC2 spoofed bridge** : any page/frame could post `loaded` (token fixation, user data injected into any page) or `close-widget`. Fix: `loaded`/close only when `currentUrl` is the widget origin + path, `loaded` once per load, token must be JWT-shaped and <= 4096 chars, user script injected only under the same check. Residual risk (hostile iframe inside /widget) is a code comment. Tests: other page -> no write, no script; spoof does not use up the real `loaded`; malformed/oversized token; close only on widget page.
**SEC7 navigation** : the whole origin was allowed (dashboard login, /hc). Fix: main frame stays only on the widget path; other same-origin and external http(s)/mailto/tel go to the OS browser; subframes: widget origin or https. Tests in `bridge_test` and through the fake navigation delegate.
**SEC4 / SEC5 / SEC10** : `baseUrl` through `validateBaseUrl` (error -> `onError`, nothing loaded); iOS keychain `first_unlock_this_device`; `generateScripts` errors (non-JSON attributes) -> `onError`; remote avatars https only.
**F16** : `onAttachFile!` at call time; now null-safe (Android-only path, covered by the null-safe code, not by a test: needs the Android platform class).

## Native chat (F5, F6, F17, F18, F11 duplicate, SEC4, SEC10)
**F5** callbacks captured once: the controller's `callbacks` is updated in `didUpdateWidget`. Test: parent rebuilds A -> B, error reaches B only.
**F6** failed client start left sends "sending" forever: queued messages are marked failed and the queue is cleared, later sends fail at once, the view shows `connectionErrorText` + Retry (`controller.retry()`). Tests: controller (queue, later send, retry, retry no-op) and widget (banner, retry, l10n).
**F17** page/dialog/view repeated the callbacks and the dialog lacked some: one `ChatwootChatInteractions`; `clientFactory` is test-only; `Message` re-exported.
**F18** theme was resolved in page, view and dialog: resolved once in the view and handed to the header builder; avatar colour uses a stable char-code fold (`ChatwootChatTheme.avatarColorFor`). The page no longer sets a Scaffold background (the view paints it).
**F11 (UI part)** bulk load uses the shared `sortMessagesOldestFirst` (numeric id tie-break), then a stable time sort; the lexicographic id compare is gone.
**SEC4** `allowInsecure` flows options -> controller -> factory. **SEC10** server avatars: https only.

## Test quality
`chatwoot_widget_test` now runs on a recording fake `WebViewPlatform` (`fake_webview_platform.dart`: controller, cookie manager, navigation delegate, shared event log). The chat widget tests no longer use `runAsync` or `pumpAndSettle`; `FakeFactory.completer` is `late` (a Completer created in `setUp` does not deliver errors to listeners in the fake-async zone). `example/test/widget_test.dart` rewritten (the old counter test was stale/removed).
Mutation-checked (each mutation made a test fail): F4 guard, SEC2 page gate, SEC2 once-per-load, SEC1 wipe on switch, SEC1 static clear, token shape, main-frame path rule, http subframe rule, SEC10 script errors, SEC4 widget validation, F6 failing queued sends, F5 callbacks swap, https avatar, stable hash, allowInsecure pass-through.

## Not done
See the report: SEC7 `window.open`/popup device check (needs a device), SEC2 hostile iframe inside /widget (documented residual risk).
