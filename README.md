[![Pub Version](https://img.shields.io/pub/v/chatwoot_sdk?color=blueviolet)](https://pub.dev/packages/chatwoot_sdk)

# Integrate Chatwoot with a Flutter app

Talk to your visitors in real time from a Flutter app: a ready native chat screen (`ChatwootChat`, three styles in light and dark) on an *API inbox* of [Chatwoot](https://github.com/chatwoot/chatwoot), or your own UI on `ChatwootClient`.

The `example/` app shows the three styles on demo data (no server needed): `cd example && flutter run`.

## 1. Install

```
flutter pub add chatwoot_sdk
```

Requires Dart `^3.13.0` and Flutter `>=3.47.0`. Everything public is exported from `package:chatwoot_sdk/chatwoot_sdk.dart`.

## 2. Native chat

Create an API channel on your server ([docs](https://www.chatwoot.com/docs/product/channels/api/create-channel)) and take its *inbox identifier*.

### Full-screen page

```dart
import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';

const options = ChatwootChatOptions(
  baseUrl: 'https://chat.example.com',
  inboxIdentifier: 'inbox-identifier',
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
| `inboxIdentifier` | required | Identifier of the API inbox. |
| `user` | `null` | `ChatwootUser` attached to the contact. |
| `enablePersistence` | `true` | Keep contact, conversation and messages on disk (encrypted). `false`: memory only. |
| `allowInsecure` | `false` | Allow plain `http://` for non-loopback hosts. Development only. |
| `style` | `smoothSilk` | `ChatwootChatStyle`: `smoothSilk` (tonal bubbles), `minimalClean` (agent replies without bubbles), `threadFeed` (full-width rows with avatar and name). Each has light and dark. |
| `theme` | from the app theme | `ChatwootChatTheme` (a `ThemeExtension`; may also be registered in `ThemeData.extensions`): brightness, optional `fontFamily` / `accentColor` / `backgroundColor` overrides. The style keeps its own palette and font (Manrope / Geist / Onest via `google_fonts`). |
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
    onConversationResolved: () {},
    onError: (error) => debugPrint('${error.type}: ${error.cause}'),
  );

  final client = await ChatwootClient.create(
    baseUrl: 'https://chat.example.com',
    inboxIdentifier: 'inbox-identifier',
    user: ChatwootUser(identifier: 'user-42', name: 'Jane', email: 'jane@example.com'),
    callbacks: callbacks,
  );
  await client.loadMessages();
  return client;
}

Future<void> send(ChatwootClient client) =>
    client.sendMessage(content: 'Hello', echoId: DateTime.now().microsecondsSinceEpoch.toString());
```

- `create()` completes after the first contact/conversation refresh. Failures arrive via `onError` and are not thrown; only an invalid `baseUrl` throws an `ArgumentError`.
- `sendMessage` carries your temporary `echoId`; `onMessageSent`/`onError` give it back. Pass `attachments: [ChatwootUpload.file(name: ..., path: ...)]` (or `ChatwootUpload.bytes` on web) to send files; `content` may then be empty.
- `sendAction(ChatwootActionType.update_presence)` returns `false` while the realtime connection is not subscribed.
- `onConnectionStateChanged` reports the realtime connection (`ChatwootConnectionState`).
- Call `await client.dispose()` when done (safe to call twice).
- Persisted clients with the same `baseUrl`, `inboxIdentifier`, `user.identifier` and `user.identifierHash` share their data.

## 4. Sign out

On logout, forget everything this SDK stored for the user. Dispose running clients first.

```dart
await chatwootSignOut(
  baseUrl: 'https://chat.example.com',
  inboxIdentifier: 'inbox-identifier',
  user: currentUser, // same identifier / identifierHash as used before
);
```

`ChatwootClient.clearAllData()` removes all persisted data of every user.

## 5. `ChatwootUser`

`identifier`, `name`, `email`, `avatarUrl`, `customAttributes`, `identifierHash`. `identifierHash` (HMAC of the identifier) must be computed by **your backend** with the inbox secret; never embed the secret in the app. `identifierHash` and `customAttributes` are never written to disk.

## 6. https and `allowInsecure`

`baseUrl` must be `https://`. Plain `http://` is accepted only for `localhost`, `127.0.0.1` and `10.0.2.2`, or for any host when `allowInsecure: true` (development only). Android 9+ also needs `android:usesCleartextTraffic="true"` for cleartext; iOS needs an App Transport Security exception.

## 7. Platform notes

- **Android**: Declare the `INTERNET` permission in your app manifest, and `RECORD_AUDIO` for voice messages. `minSdk` follows `flutter_secure_storage`, `record` and `file_picker` (see their READMEs).
- **iOS**: add `NSMicrophoneUsageDescription` (voice messages) and `NSPhotoLibraryUsageDescription` (photos) to `Info.plist`. Deployment target per `flutter_secure_storage`, `record`, `just_audio`. Keychain entries use `first_unlock_this_device`.
- **Web**: the browser asks for the microphone; files are read into memory.
- Persisted data uses the platform keystore/keychain; they need a device with secure storage available. If storage cannot be opened the client still works in memory and reports `STORAGE_FAILED`.

## 8. Security notes

- The server and its agents are trusted: messages are rendered as plain text, never executed.
- `identifierHash` must be signed by your backend; the SDK is not a trust anchor.
- The websocket has no connection auth beyond the `pubsub_token`.
- There is no certificate pinning by default; add your own if your threat model needs it.
- Rooted or jailbroken devices are out of scope.
- `onError` text may end up in your crash reporter; it can include server response details, so treat it as diagnostic data.

## 9. Development

See [doc/Develop.md](doc/Develop.md). Generated `*.g.dart` files are gitignored: run `dart run build_runner build --delete-conflicting-outputs` after cloning.
