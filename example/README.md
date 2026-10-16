# Zukko Chat example

A small app that runs the `zukko_chat_flutter` chat against your **real**
Zukko Chat server. The code is written to be read top to bottom.

## Run

You need an inbox of type "Website" on a Zukko Chat server. Pass its values
with `--dart-define` (nothing is hardcoded, nothing secret is committed):

```
flutter run \
  --dart-define=ZUKKO_BASE_URL=https://chat.example.com \
  --dart-define=ZUKKO_WEBSITE_TOKEN=<website token> \
  --dart-define=ZUKKO_USER_ID=user-42 \
  --dart-define=ZUKKO_USER_HASH=<hmac of the user id>
```

`ZUKKO_BASE_URL` (https only) and `ZUKKO_WEBSITE_TOKEN` are required.
`ZUKKO_USER_ID` and `ZUKKO_USER_HASH` are optional: without a user id you chat
as an anonymous visitor. Without the required values the app shows a screen
that tells you what to run.

## Where to get the values

In the Zukko Chat admin open **Settings -> Inboxes -> your inbox ->
Configuration**.

- **Website token** and **base URL**: in the "web widget" snippet shown there
  (`websiteToken: '...'` and `BASE_URL: '...'`).
- **HMAC token** (only needed for identified users): same page, under
  **Identity validation**. It signs the user id.
- **User hash**: `HMAC-SHA256(userId)` as hex, keyed with the HMAC token. To get
  a test value:

  ```
  echo -n "user-42" | openssl dgst -sha256 -hmac "<HMAC token>"
  ```

  Use the same string as `ZUKKO_USER_ID`. In a real app your **backend**
  computes this hash after login and sends it to the app. The HMAC token must
  never be put into the app.

## Files, in reading order

| File | What it shows |
|---|---|
| `lib/main.dart` | Entry point, `MaterialApp`, light/dark theme (the chat follows it). |
| `lib/home_screen.dart` | Choosing a style (`ZukkoChatStyle`), dark mode, opening the chat, sign out. |
| `lib/live/live_config.dart` | Reading `--dart-define`, building `ZukkoChatUser` (identifier vs identifierHash). |
| `lib/live/live_chat_screen.dart` | The `ZukkoChat` widget with every public parameter of `ZukkoChatOptions`, `ZukkoChatTheme`, `ZukkoChatCallbacks` and `ZukkoChatInteractions` written out and explained; sign-out flow. |
| `lib/live/not_configured_view.dart` | The screen shown while the dart-defines are missing. |

Run the tests with `flutter test` (no network needed).
