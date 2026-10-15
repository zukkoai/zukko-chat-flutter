import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';

/// The messages of one chat and how they are keyed.
///
/// Messages live in [chat] (oldest first) under a stable key: the client's
/// `echoId` for messages sent from here, the server id otherwise. Once the
/// server confirms a sent message its id is aliased to the echo key
/// ([alias]), so the server's own `message.created` echo updates the same
/// bubble instead of adding a second one. Single events use
/// `insertMessage`/`updateMessage`; only bulk loads use `setMessages`.
///
/// One ordering for everything: by `createdAt` (a missing date counts as the
/// epoch), equal dates keep the order they arrived in. The server list is
/// put into time-then-id order before it reaches [bulkUpsert].
class ChatMessageStore {
  ChatMessageStore(this.chat);

  /// Backing controller of the flutter_chat_ui `Chat` widget.
  final InMemoryChatController chat;

  final _byKey = <String, Message>{};
  final _keyByServerId = <int, String>{};

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Message? operator [](String key) => _byKey[key];

  /// The list key of server message [serverId]: its echo key once aliased.
  String keyOfServer(int serverId) =>
      _keyByServerId[serverId] ?? serverId.toString();

  /// The last message of the list, if any.
  Message? get last => chat.messages.isEmpty ? null : chat.messages.last;

  /// Insert or replace one message without touching the rest of the list.
  void upsertLocal(Message message) {
    final old = _byKey[message.id];
    _byKey[message.id] = message;
    if (old != null) {
      unawaited(chat.updateMessage(old, message));
      return;
    }
    final list = chat.messages;
    final at = message.createdAt;
    var index = list.length;
    // New messages are almost always the newest: scan from the end.
    while (at != null &&
        index > 0 &&
        (list[index - 1].createdAt?.isAfter(at) ?? false)) {
      index--;
    }
    unawaited(chat.insertMessage(message, index: index));
  }

  /// A message the server sent: replaces the local bubble of the same key
  /// (keeping what it knows better, see [merge]) or is added. With
  /// [onlyExisting] an unknown message is ignored (an update event).
  void upsertServer(Message converted, {bool onlyExisting = false}) {
    final existing = _byKey[converted.id];
    if (existing == null && onlyExisting) return;
    upsertLocal(existing == null ? converted : merge(existing, converted));
  }

  /// Keeps what the local bubble knows better than the server (position and
  /// delivery state), takes the server's text and author.
  static Message merge(Message existing, Message incoming) => incoming.copyWith(
    createdAt: existing.createdAt,
    status: _rank(existing.status) > _rank(incoming.status)
        ? existing.status
        : incoming.status,
  );

  static int _rank(MessageStatus? s) => switch (s) {
    MessageStatus.sending || MessageStatus.error => 0,
    MessageStatus.delivered => 1,
    MessageStatus.seen => 2,
    null => 2,
    _ => 1,
  };

  /// The server accepted [echoId] as server message [serverId]: later events
  /// for it land on the echo's bubble. If the socket echo beat the REST
  /// response and already added a bubble, that one is removed (one bubble).
  void alias(int serverId, String echoId) {
    final serverKey = serverId.toString();
    final duplicate = _keyByServerId[serverId] == null
        ? _byKey[serverKey]
        : null;
    _keyByServerId[serverId] = echoId;
    if (duplicate != null) {
      _byKey.remove(serverKey);
      unawaited(chat.removeMessage(duplicate));
    }
  }

  /// Marks the bubble [key] as failed to send.
  void markFailed(String key) {
    final m = _byKey[key];
    if (m != null) upsertLocal(m.copyWith(status: MessageStatus.error));
  }

  /// Adds or merges [messages] (already oldest first) and re-sorts the list
  /// once. Existing keys keep their slot among equal dates.
  void bulkUpsert(List<Message> messages) {
    if (messages.isEmpty) return;
    for (final m in messages) {
      final existing = _byKey[m.id];
      _byKey[m.id] = existing == null ? m : merge(existing, m);
    }
    // List.sort is not stable: the arrival index breaks equal dates.
    final ordered = [for (final (i, m) in _byKey.values.indexed) (m, i)]
      ..sort((a, b) {
        final byTime = (a.$1.createdAt ?? _epoch).compareTo(
          b.$1.createdAt ?? _epoch,
        );
        return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
      });
    unawaited(chat.setMessages([for (final (m, _) in ordered) m]));
  }

  /// Drops everything except the messages whose keys are in [keep] (the
  /// session now belongs to another contact; unsent messages stay).
  void keepOnly(bool Function(String key) keep) {
    final kept = [
      for (final m in chat.messages)
        if (keep(m.id)) m,
    ];
    _byKey
      ..clear()
      ..addEntries([for (final m in kept) MapEntry(m.id, m)]);
    _keyByServerId.clear();
    unawaited(chat.setMessages(kept));
  }
}
