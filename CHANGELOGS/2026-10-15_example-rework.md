# Example app rework

## What
- Home screen (`HomeScreen`, was `StylesHomeScreen`) now has two parts: the three chat styles on offline demo data, and a "Live chat" entry.
- `LiveChatScreen` shows the real API: `ZukkoChat` with `ZukkoChatOptions(baseUrl, websiteToken, user: ZukkoChatUser(...))`, `onError` / `onConnectionStateChanged` / `onConversationUpdated` callbacks, and sign-out (`zukkoChatSignOut`) on the chat's "more" button. Config comes from `--dart-define` (`ZUKKO_BASE_URL`, `ZUKKO_WEBSITE_TOKEN`, `ZUKKO_USER_ID`, `ZUKKO_USER_HASH`); without it a "not configured" screen is shown. Nothing is hardcoded; the user hash must come from the app backend.
- `demo_client.dart` split: client behaviour (`demo/demo_client.dart`) and fixtures (`demo/demo_conversation.dart`).

## Why
- E1: demo uses `clientFactory` as a normal option, no lint suppression.
- E2: `noSuchMethod` removed; every `ZukkoChatClient` member is implemented (incl. `resume()`).
- E3/E4/E5/E6: SRP split, naming, trimmed `pubspec.yaml`, real-API sample, wider tests (each style, live placeholder, `LiveConfig`).

## Run live mode
`cd example && flutter run --dart-define=ZUKKO_BASE_URL=... --dart-define=ZUKKO_WEBSITE_TOKEN=... [--dart-define=ZUKKO_USER_ID=... --dart-define=ZUKKO_USER_HASH=...]`
