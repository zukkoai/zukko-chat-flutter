[![Pub Version](https://img.shields.io/pub/v/chatwoot_sdk?color=blueviolet)](https://pub.dev/packages/chatwoot_sdk)

# Integrate Chatwoot with a Flutter app

Talk to your visitors in real time from a Flutter app: a ready native chat screen (`ChatwootChat`, three styles in light and dark) on a *Website inbox* (Widget API) of the Zukko chat server, or your own UI on `ChatwootClient`.

The `example/` app shows the three styles on demo data (no server needed): `cd example && flutter run`.

## 1. Install

```
flutter pub add chatwoot_sdk
```

Requires Dart `^3.13.0` and Flutter `>=3.47.0`. Everything public is exported from `package:chatwoot_sdk/chatwoot_sdk.dart`.

## 2. Native chat

### Server setup

1. In the chat server create a **Website** inbox (the web widget channel) and copy its **website token** (Inbox settings, Configuration, the `websiteToken` in the widget script). This is what the app passes as `websiteToken`; it is public, like the token on a website.
2. To identify logged-in users, **Enforce identity validation** on the inbox is **required**. Without it anyone can claim any `identifier` (and read that user's conversation); with it the server accepts a user only with a valid `identifierHash`. A `user.identifier` without `identifierHash` is reported once as `IDENTITY_NOT_VERIFIED` (a warning, the session continues).
3. Your **backend** computes `identifierHash = hex(HMAC-SHA256(inbox HMAC token, user identifier))` and hands it to the app after login. The inbox HMAC token is a secret: it must never ship in the app.

Without a `user` the visitor is anonymous. A `user` with an `identifier` never falls back to an anonymous session: if the server rejects the hash (`INVALID_IDENTIFIER_HASH`, terminal, no retry button) or `set_user` fails for any other reason (5xx, timeout, 404, 422: `IDENTIFY_FAILED`, retryable, the banner has a retry button) the chat does not become ready: no messages are sent or fetched and there is no realtime connection until a later attempt succeeds. A user without an `identifier` (name/email only) stays anonymous if `set_user` fails and gets an `IDENTIFY_FAILED` warning.

### Full-screen page

```dart
import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';

const options = ChatwootChatOptions(
  baseUrl: 'https://chat.example.com',
  websiteToken: 'website-token',
);

void openChat(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatwootChat(
        options: options,
        title: 'Support',
        callbacks: ChatwootCallbacks(
          onError: (e) => debugPrint('chat error: ${e.cause} (${e.type})'),
        ),
        interactions: ChatwootChatInteractions(
          onSendPressed: (text) => debugPrint('sent ${text.length} chars'),
        ),
      ),
    ),
  );
}
```

### `ChatwootChatOptions`

| Name | Default | Description |
|---|---|---|
| `baseUrl` | required | Installation URL. Must be `https` (see "https" below). |
| `websiteToken` | required | Website token of the Website (web widget) inbox. |
| `user` | `null` | `ChatwootUser` attached to the contact. |
| `enablePersistence` | `true` | Keep contact, conversation and messages on disk (encrypted). `false`: memory only. |
| `allowInsecure` | `false` | Allow plain `http://` for non-loopback hosts. Development only. |
| `style` | `smoothSilk` | `ChatwootChatStyle`: `smoothSilk` (tonal bubbles), `minimalClean` (agent replies without bubbles), `threadFeed` (full-width rows with avatar and name). Each has light and dark. |
| `theme` | from the app theme | `ChatwootChatTheme` (a `ThemeExtension`; may also be registered in `ThemeData.extensions`): brightness, optional `fontFamily` / `accentColor` / `backgroundColor` overrides. The style keeps its own palette and font (Manrope / Geist / Onest, bundled in the package: no network request, works offline). `fontFamily` must name a font registered in the host app. |
| `l10n` | app locale | `ChatwootL10n` texts. `null` picks the built-in translation of the locale: English, `ru`, `uz` (Latin), `uz_Cyrl`, `tr`, `kaa` (Karakalpak). Presets: `ChatwootL10n.ru`, `.uzLatn`, `.uzCyrl`, `.tr`, `.kaa`. |
| `timeFormat` | `Hm` | `intl` `DateFormat` for message time. |
| `showBranding` | `true` | Show the "Powered by zukko.ai" footer. |
| `enableAttachments` | `true` | Attachment button: photos and files (up to 40 MB each). |
| `enableVoiceMessages` | `true` | Hold-to-record microphone: voice messages up to 5 minutes (slide to cancel). Needs the microphone permission entries below. |

`ChatwootChatInteractions` carries UI events: `onEndReached`, `onEndReachedThreshold`, `onMessageLongPress`, `onMessageTap`, `onSendPressed`, `onMorePressed` (shows the header menu button).

The chat sends and shows images (several images as a grid), files and voice messages, and plays voice messages, in every style. The `Message` type in them is re-exported from `flutter_chat_core`.

`ChatwootChat` draws the style's header (title from `title`, back button when the route can pop); pass `appBar` to use your own instead.

## 3. `ChatwootClient` (your own UI)

```dart
import 'package:chatwoot_sdk/chatwoot_sdk.dart';

Future<ChatwootClient> startClient() async {
  final callbacks = ChatwootCallbacks(
    onConnectionStateChanged: (state) => debugPrint('connection: $state'),
    onPersistedMessagesRetrieved: (messages) {/* show cached messages */},
    onMessagesRetrieved: (messages) {/* show fresh messages */},
    onMessageReceived: (message) {/* an agent wrote */},
    onMessageSent: (message, echoId) {/* confirmed by the server */},
    onMessageDelivered: (message, echoId) {/* delivered */},
    onMessageUpdated: (message) {},
    onConversationStartedTyping: () {},
    onConversationStoppedTyping: () {},
    onConversationIsOnline: () {},
    onConversationIsOffline: () {},
    onConversationResolved: () {}, // the messages stay; the user may write again
    onConversationUpdated: (conversation) {}, // created / status changed
    onSessionReset: () {}, // the session now belongs to a new contact: drop shown messages
    onError: (error) => debugPrint('${error.type}: ${error.cause}'),
  );

  final client = await ChatwootClient.create(
    baseUrl: 'https://chat.example.com',
    websiteToken: 'website-token',
    user: ChatwootUser(identifier: 'user-42', name: 'Jane', email: 'jane@example.com'),
    callbacks: callbacks,
  );
  await client.loadMessages();
  return client;
}

Future<void> send(ChatwootClient client) =>
    client.sendMessage(content: 'Hello', echoId: DateTime.now().microsecondsSinceEpoch.toString());
```

- `create()` completes after the session (`/config`, `set_user`) and the first conversation refresh. Failures arrive via `onError` and are not thrown; only an invalid `baseUrl` throws an `ArgumentError`.
- `sendMessage` carries your temporary `echoId`; `onMessageSent`/`onError` give it back. Pass `attachments: [ChatwootUpload.file(name: ..., path: ...)]` (or `ChatwootUpload.bytes` on web) to send files; `content` may then be empty.
- `await client.setTyping(true)` / `false` tells the agents the user is typing; `await client.markSeen()` tells them their messages were read (the native chat does both itself). `client.config` holds the inbox branding (`WidgetConfig`) once the session exists.
- `sendAction(ChatwootActionType.update_presence)` returns `false` while the realtime connection is not subscribed.
- `onConnectionStateChanged` reports the realtime connection (`ChatwootConnectionState`).
- Call `client.resume()` when the app returns to the foreground (the native chat does it itself): it restarts realtime if it had stopped, for instance after a rejected subscription, which is otherwise retried slowly (60 s, 120 s ... up to 10 min).
- Call `await client.dispose()` when done (safe to call twice).
- Requests never follow redirects (the JWT must not travel to another host) and time out after 15 s to connect / 30 s to receive / 60 s to send.
- Persisted clients with the same `baseUrl`, `websiteToken`, `user.identifier` and `user.identifierHash` share their data.

## 4. Sign out

On logout, forget everything this SDK stored for the user. Dispose running clients first.

```dart
await chatwootSignOut(
  baseUrl: 'https://chat.example.com',
  websiteToken: 'website-token',
  user: currentUser, // same identifier as used before
);
```

It removes the records of that `identifier` under every `identifierHash` (a rotated hash leaves nothing behind); other users and inboxes are untouched. `ChatwootClient.clearAllData()` removes all persisted data of every user.

## 5. `ChatwootUser`

`identifier`, `identifierHash`, `name`, `email`, `phoneNumber`, `avatarUrl`, `customAttributes`. `identifierHash` (HMAC-SHA256 of the identifier) must be computed by **your backend** with the inbox HMAC token; never embed that token in the app. `identifierHash` and `customAttributes` are never written to disk. The user is sent with `set_user` on every start, which also updates changed fields. The same `identifier` on another device continues the same conversation.

## 6. https and `allowInsecure`

`baseUrl` must be `https://`. Plain `http://` is accepted only for `localhost`, `127.0.0.1` and `10.0.2.2`, or for any host when `allowInsecure: true` (development only). Android 9+ also needs `android:usesCleartextTraffic="true"` for cleartext; iOS needs an App Transport Security exception.

## 7. Platform notes

- **Android**: Declare the `INTERNET` permission in your app manifest, and `RECORD_AUDIO` for voice messages (`<uses-permission android:name="android.permission.RECORD_AUDIO"/>`). `minSdk` follows `flutter_secure_storage`, `record` and `file_picker` (see their READMEs).
- **iOS**: add `NSMicrophoneUsageDescription` (voice messages) and `NSPhotoLibraryUsageDescription` (photos) to `Info.plist`, e.g. `<key>NSMicrophoneUsageDescription</key><string>Record voice messages for support</string>`. Deployment target per `flutter_secure_storage`, `record`, `just_audio`. Keychain entries use `first_unlock_this_device`.
- **Web**: the browser asks for the microphone; files are read into memory.
- Persisted data uses the platform keystore/keychain; they need a device with secure storage available. If storage cannot be opened the client still works in memory and reports `STORAGE_FAILED`.

## 8. Security notes

- The server and its agents are trusted: messages are rendered as plain text, never executed.
- `identifierHash` must be signed by your backend; the SDK is not a trust anchor.
- The session is a JWT (`X-Auth-Token`) kept only in the encrypted store; the websocket has no connection auth beyond the `pubsub_token`. Neither is ever logged.
- There is no certificate pinning by default; add your own if your threat model needs it.
- Rooted or jailbroken devices are out of scope.
- `onError` text may end up in your crash reporter; it can include server response details, so treat it as diagnostic data.

## 9. Development

See [doc/Develop.md](doc/Develop.md). Generated `*.g.dart` files are gitignored: run `dart run build_runner build --delete-conflicting-outputs` after cloning.
