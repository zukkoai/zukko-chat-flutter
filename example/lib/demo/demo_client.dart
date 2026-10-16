import 'dart:async';

import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'demo_conversation.dart';

const _firstMessageId = 100;
const _sentAfter = Duration(milliseconds: 400);
const _typingAfter = Duration(milliseconds: 900);
const _replyAfter = Duration(milliseconds: 2600);

/// Offline stand-in for [ZukkoChatClient], so the chat styles can be checked
/// without a server: it loads a fixed conversation and answers every sent
/// message after a short "typing". Every public member is implemented.
class DemoZukkoChatClient implements ZukkoChatClient {
  DemoZukkoChatClient._(this.callbacks);

  /// Same signature as [ZukkoChatClient.create] (a [ZukkoChatClientFactory]).
  static Future<ZukkoChatClient> create({
    required String baseUrl,
    required String websiteToken,
    ZukkoChatUser? user,
    bool enablePersistence = true,
    bool allowInsecure = false,
    ZukkoChatCallbacks? callbacks,
  }) async => DemoZukkoChatClient._(callbacks);

  final ZukkoChatCallbacks? callbacks;

  final _timers = <Timer>[];
  var _nextId = _firstMessageId;
  var _disposed = false;

  // No branding offline.
  @override
  ZukkoChatConfig? get config => null;

  @override
  Future<void> loadMessages() async {
    callbacks?.onMessagesRetrieved?.call(demoConversation());
    callbacks?.onConversationIsOnline?.call();
  }

  @override
  Future<void> sendMessage({
    required String content,
    required String echoId,
    List<ZukkoChatUpload> attachments = const [],
    int? replyTo,
  }) async {
    final sent = demoMessage(
      _nextId++,
      content: content.isEmpty ? null : content,
      mine: true,
      attachments: [for (final a in attachments) demoHostedAttachment(a)],
    );
    _after(_sentAfter, () => callbacks?.onMessageSent?.call(sent, echoId));
    _after(_typingAfter, () => callbacks?.onConversationStartedTyping?.call());
    _after(_replyAfter, () {
      callbacks?.onConversationStoppedTyping?.call();
      callbacks?.onMessageReceived?.call(
        demoMessage(
          _nextId++,
          content: content.isEmpty
              ? 'Faylingizni oldim, rahmat.'
              : 'Qabul qildim: "$content". Tez orada javob beraman.',
        ),
      );
    });
  }

  @override
  Future<void> markSeen() async {}

  @override
  Future<void> setTyping(bool on) async {}

  @override
  void resume() {}

  @override
  Future<bool> sendAction(ZukkoChatActionType action) async => true;

  @override
  Future<void> clearClientData() async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
  }

  void _after(Duration delay, void Function() action) => _timers.add(
    Timer(delay, () {
      if (!_disposed) action();
    }),
  );
}
