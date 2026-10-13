[![Pub Version](https://img.shields.io/pub/v/chatwoot_sdk?color=blueviolet)](https://pub.dev/packages/chatwoot_sdk)

# Integrate Chatwoot with a Flutter app

Talk to your visitors in real time from a Flutter app. Two independent ways to embed [Chatwoot](https://github.com/chatwoot/chatwoot):

1. **Native chat** (`ChatwootChat`, `ChatwootChatDialog`, or build your own UI on `ChatwootClient`): talks to an *API inbox*.
2. **Web widget** (`ChatwootWidget`): shows the Chatwoot website widget in a webview (*website channel*).

<img src="https://user-images.githubusercontent.com/22669874/225545427-bd3fe38c-d116-4286-b542-67b03a51e2d2.jpg" alt="chatwoot screenshot" height="560"/>

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
        appBar: AppBar(title: const Text('Support')),
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

### Dialog

```dart
Future<void> openDialog(BuildContext context) => ChatwootChatDialog.show(
      context,
      options: options,
      title: 'Support',
    );
```

### `ChatwootChatOptions`

| Name | Default | Description |
|---|---|---|
| `baseUrl` | required | Installation URL. Must be `https` (see "https" below). |
| `inboxIdentifier` | required | Identifier of the API inbox. |
| `user` | `null` | `ChatwootUser` attached to the contact. |
| `enablePersistence` | `true` | Keep contact, conversation and messages on disk (encrypted). `false`: memory only. |
| `allowInsecure` | `false` | Allow plain `http://` for non-loopback hosts. Development only. |
| `theme` | from `ColorScheme` | `ChatwootChatTheme` (a `ThemeExtension`; may also be registered in `ThemeData.extensions`). |
| `l10n` | English | `ChatwootL10n` texts. |
| `timeFormat` | `Hm` | `intl` `DateFormat` for message time. |
| `showUserAvatars`, `showUserNames`, `showBranding` | `true` | UI switches. |
| `style` | `classic` | `ChatwootChatStyle` (only `classic` for now). |

`ChatwootChatInteractions` carries UI events: `onEndReached`, `onEndReachedThreshold`, `onMessageLongPress`, `onMessageTap`, `onSendPressed`. The `Message` type in them is re-exported from `flutter_chat_core`.

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
- `sendMessage` carries your temporary `echoId`; `onMessageSent`/`onError` give it back.
- `sendAction(ChatwootActionType.update_presence)` returns `false` while the realtime connection is not subscribed.
- `onConnectionStateChanged` reports the realtime connection (`ChatwootConnectionState`).
- Call `await client.dispose()` when done (safe to call twice).
- Persisted clients with the same `baseUrl`, `inboxIdentifier`, `user.identifier` and `user.identifierHash` share their data.

## 4. Web widget

Create a website channel ([docs](https://www.chatwoot.com/docs/channels/website)) and use its *website token*.

```dart
ChatwootWidget(
  websiteToken: 'website-token',
  baseUrl: 'https://chat.example.com',
  user: ChatwootUser(identifier: 'user-42', name: 'Jane', email: 'jane@example.com'),
  locale: 'en',
  closeWidget: () => Navigator.of(context).maybePop(),
  onAttachFile: pickFiles, // Android only; returns a list of file URIs
  onLoadStarted: () {},
  onLoadProgress: (progress) {},
  onLoadCompleted: () {},
  onError: (description) => debugPrint('widget error: $description'),
)
```

The conversation token is kept in secure storage per `baseUrl` + `websiteToken` + user. Custom `tokenStore` and `allowInsecure` are available.

## 5. Sign out

On logout, forget everything this SDK stored for the user. Dispose running clients and remove the widget first.

```dart
await chatwootSignOut(
  baseUrl: 'https://chat.example.com',
  inboxIdentifier: 'inbox-identifier', // native client data
  websiteToken: 'website-token',       // webview token + cookies/storage/cache
  user: currentUser,                   // same identifier / identifierHash as used before
);
```

Either identifier may be omitted. `ChatwootClient.clearAllData()` removes all persisted native data of every user.

## 6. `ChatwootUser`

`identifier`, `name`, `email`, `avatarUrl`, `customAttributes`, `identifierHash`. `identifierHash` (HMAC of the identifier) must be computed by **your backend** with the inbox secret; never embed the secret in the app. `identifierHash` and `customAttributes` are never written to disk.

## 7. https and `allowInsecure`

`baseUrl` must be `https://`. Plain `http://` is accepted only for `localhost`, `127.0.0.1` and `10.0.2.2`, or for any host when `allowInsecure: true` (development only). Android 9+ also needs `android:usesCleartextTraffic="true"` for cleartext; iOS needs an App Transport Security exception.

## 8. Platform notes

- **Android**: Declare the `INTERNET` permission in your app manifest. `ChatwootWidget` file upload (`onAttachFile`) is Android only; your picker may need `READ_MEDIA_IMAGES`/storage permissions. `minSdk` follows `webview_flutter_android` and `flutter_secure_storage` (see their READMEs).
- **iOS**: deployment target per `webview_flutter_wkwebview` / `flutter_secure_storage`. Keychain entries use `first_unlock_this_device`.
- Persisted data and the widget token use the platform keystore/keychain; they need a device with secure storage available. If storage cannot be opened the client still works in memory and reports `STORAGE_FAILED`.

## 9. Security notes

- The server and its agents are trusted: messages are rendered as plain text, never executed.
- `identifierHash` must be signed by your backend; the SDK is not a trust anchor.
- The webview runs JavaScript (required by the widget). A hostile iframe inside the widget page is a residual risk; the bridge ignores messages from other pages.
- The widget URL carries `website_token` and conversation id (web widget protocol).
- The websocket has no connection auth beyond the `pubsub_token`.
- There is no certificate pinning by default; add your own if your threat model needs it.
- Rooted or jailbroken devices are out of scope.
- `onError` text may end up in your crash reporter; it can include server response details, so treat it as diagnostic data.

## 10. Development

See [doc/Develop.md](doc/Develop.md). Generated `*.g.dart` files are gitignored: run `dart run build_runner build --delete-conflicting-outputs` after cloning.
