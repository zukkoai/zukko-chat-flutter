import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

/// Server settings and the visitor's identity, read from `--dart-define` so no
/// secret is ever committed. Run with:
///
/// ```
/// flutter run \
///   --dart-define=ZUKKO_BASE_URL=https://chat.example.com \
///   --dart-define=ZUKKO_WEBSITE_TOKEN=... \
///   --dart-define=ZUKKO_USER_ID=user-42 \
///   --dart-define=ZUKKO_USER_HASH=...
/// ```
///
/// `String.fromEnvironment` is resolved at compile time, which is why the
/// constructor is `const` and why the values come from build flags rather than
/// a file read at runtime. Tests construct a [LiveConfig] with explicit values.
class LiveConfig {
  const LiveConfig({
    this.baseUrl = const String.fromEnvironment('ZUKKO_BASE_URL'),
    this.websiteToken = const String.fromEnvironment('ZUKKO_WEBSITE_TOKEN'),
    this.userId = const String.fromEnvironment('ZUKKO_USER_ID'),
    this.userHash = const String.fromEnvironment('ZUKKO_USER_HASH'),
  });

  /// Your Zukko Chat server, https only (the SDK refuses plain http).
  final String baseUrl;

  /// Identifies the website/app inbox on that server.
  final String websiteToken;

  /// Your own id for the logged-in user (database id, uuid, ...). Empty means
  /// the visitor is anonymous.
  final String userId;

  /// HMAC-SHA256 of [userId], hex encoded, keyed with the inbox's "HMAC token"
  /// (Identity validation). It proves to the server that [userId] really is
  /// who your app says it is, so nobody can impersonate another user.
  ///
  /// In a real app YOUR BACKEND computes it right after login and returns it
  /// together with the user id. The HMAC token itself must NEVER ship in the
  /// app: anything in an APK/IPA can be extracted. Here it comes from a
  /// dart-define only so you can try the identified flow with a test value.
  final String userHash;

  /// True when the two values every chat needs are present.
  bool get isConfigured => baseUrl.isNotEmpty && websiteToken.isNotEmpty;

  /// The visitor's identity, or null for an anonymous visitor.
  ///
  /// - `identifier` is the id the server links the contact to. The same
  ///   identifier on another device resumes the same conversation.
  /// - `identifierHash` is optional. Without it the server accepts the
  ///   identifier only if identity validation is off; with validation on and a
  ///   wrong or missing hash the SDK fails closed (no anonymous fallback).
  /// - `name`, `email`, `phoneNumber` (E.164) are profile data shown to agents.
  ///   `avatarUrl` and `customAttributes` exist too.
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
