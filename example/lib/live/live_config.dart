import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

/// Live-chat settings, read from `--dart-define` so no secret is ever
/// committed. Run with:
///
/// ```
/// flutter run \
///   --dart-define=ZUKKO_BASE_URL=https://chat.example.com \
///   --dart-define=ZUKKO_WEBSITE_TOKEN=... \
///   --dart-define=ZUKKO_USER_ID=user-42 \
///   --dart-define=ZUKKO_USER_HASH=...
/// ```
class LiveConfig {
  const LiveConfig({
    this.baseUrl = const String.fromEnvironment('ZUKKO_BASE_URL'),
    this.websiteToken = const String.fromEnvironment('ZUKKO_WEBSITE_TOKEN'),
    this.userId = const String.fromEnvironment('ZUKKO_USER_ID'),
    this.userHash = const String.fromEnvironment('ZUKKO_USER_HASH'),
  });

  final String baseUrl;
  final String websiteToken;
  final String userId;

  /// HMAC of [userId]. In a real app the backend computes it with the
  /// inbox secret and hands it to the app after login; it must never be
  /// computed (or the secret stored) on the device.
  final String userHash;

  bool get isConfigured => baseUrl.isNotEmpty && websiteToken.isNotEmpty;

  /// Null (anonymous visitor) when no user id is given.
  ZukkoChatUser? get user => userId.isEmpty
      ? null
      : ZukkoChatUser(
          identifier: userId,
          identifierHash: userHash.isEmpty ? null : userHash,
          name: 'Demo user',
          email: 'demo@example.com',
          phoneNumber: '+998901234567',
        );
}
