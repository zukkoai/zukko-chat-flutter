# Zukko Chat Flutter SDK

A native Flutter SDK (iOS and Android) that embeds Zukko Chat customer support
into mobile apps. It talks to the Zukko Chat server's Widget API and ships a
ready-made chat screen you can drop into any app.

## Features

- Real-time messaging over WebSocket
- File, image and voice attachments
- Full-screen image viewer
- Three built-in chat styles (Smooth Silk, Minimal Clean, Thread Feed) with light and dark themes
- Custom font support
- Localization: English, Russian, Uzbek (Latin and Cyrillic), Turkish, Karakalpak
- Secure user identity (HMAC)
- Encrypted local storage

## Installation

```
flutter pub add zukko_chat_flutter
```

## Quick start

```dart
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

ZukkoChat(
  options: ZukkoChatOptions(
    baseUrl: 'https://chat.example.com',
    websiteToken: '<website-token>',
  ),
)
```

## License

MIT, see [LICENSE](LICENSE).

Originally based on [chatwoot/chatwoot-flutter-sdk](https://github.com/chatwoot/chatwoot-flutter-sdk) (MIT).
