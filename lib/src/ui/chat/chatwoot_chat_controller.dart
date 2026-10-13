import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/chatwoot_callbacks.dart';
import '../../core/chatwoot_client.dart';
import '../../core/chatwoot_client_exception.dart';
import '../../data/models/chatwoot_message.dart';
import '../../data/models/chatwoot_user.dart';
import '../../shared/message_order.dart';
import '../../shared/sdk_log.dart';
import '../l10n/chatwoot_l10n.dart';
import 'chatwoot_chat_options.dart';

/// Signature of [ChatwootClient.create]; the seam tests use to inject a fake.
typedef ChatwootClientFactory = Future<ChatwootClient> Function({
  required String baseUrl,
  required String inboxIdentifier,
  ChatwootUser? user,
  bool enablePersistence,
  bool allowInsecure,
  ChatwootCallbacks? callbacks,
});

enum ChatwootChatStatus { offline, online, typing }

const _meId = 'chatwoot-me';
const _agentId = 'chatwoot-agent';
const _systemId = 'chatwoot-system';
const _resolvedPrefix = 'chatwoot-resolved-';

/// Owns the [ChatwootClient] lifecycle and the message list of one chat.
///
/// Messages live in [chat] (oldest first) under a stable key: the client's
/// `echoId` for messages sent from here, the server id otherwise. Once the
/// server confirms a sent message its id is aliased to the echo key, so the
/// server's own `message.created` echo updates the same bubble instead of
/// adding a second one. Single events use `insertMessage`/`updateMessage`;
/// only bulk loads use `setMessages`.
class ChatwootChatController extends ChangeNotifier {
  ChatwootChatController(
    this.options, {
    this.callbacks,
    ChatwootClientFactory clientFactory = ChatwootClient.create,
    InMemoryChatController? chat,
  }) : _factory = clientFactory,
       chat = chat ?? InMemoryChatController(),
       l10n = options.l10n {
    _users[_meId] = User(
      id: _meId,
      name: options.user?.name,
      imageSource: options.user?.avatarUrl,
    );
    unawaited(_start());
  }

  final ChatwootChatOptions options;
  final ChatwootClientFactory _factory;

  /// Consumer callbacks; the view keeps them current across rebuilds.
  ChatwootCallbacks? callbacks;

  /// Backing controller of the flutter_chat_ui `Chat` widget.
  final InMemoryChatController chat;

  /// Strings used for generated messages; the view keeps it current.
  ChatwootL10n l10n;

  final _users = <String, User>{};
  final _byKey = <String, Message>{};
  final _keyByServerId = <int, String>{};
  final _pending = <String, String>{}; // echoId -> text, until client is ready
  final _uuid = const Uuid();

  ChatwootClient? _client;
  bool _disposed = false;
  int _resolvedCount = 0;
  ChatwootChatStatus _status = ChatwootChatStatus.offline;
  ChatwootClientException? _error;

  String get currentUserId => _meId;
  ChatwootChatStatus get status => _status;

  /// True once the client exists; sends before that are queued.
  bool get isReady => _client != null;

  /// Set when the client could not be created.
  ChatwootClientException? get error => _error;

  Future<User> resolveUser(String id) async => _users[id] ?? User(id: id);

  /// Tries again after [error]; no-op unless the last start failed.
  void retry() {
    if (_disposed || _error == null) return;
    _error = null;
    notifyListeners();
    unawaited(_start());
  }

  Future<void> _start() async {
    final ChatwootClient client;
    try {
      client = await _factory(
        baseUrl: options.baseUrl,
        inboxIdentifier: options.inboxIdentifier,
        user: options.user,
        enablePersistence: options.enablePersistence,
        allowInsecure: options.allowInsecure,
        callbacks: _wrapCallbacks(),
      );
    } catch (e, st) {
      sdkLog('client failed with error $e: $st');
      if (_disposed) return;
      _error = ChatwootClientException(
        e.toString(),
        ChatwootClientExceptionType.CREATE_CLIENT_FAILED,
      );
      // Nothing will ever send these: show them as failed (tap to retry).
      _pending.keys.toList().forEach(_markFailed);
      _pending.clear();
      callbacks?.onError?.call(_error!);
      notifyListeners();
      return;
    }
    if (_disposed) {
      unawaited(client.dispose());
      return;
    }
    _client = client;
    notifyListeners();
    final queued = Map.of(_pending);
    _pending.clear();
    queued.forEach((echoId, text) => unawaited(_dispatch(echoId, text)));
    try {
      await client.loadMessages();
    } catch (e) {
      sdkLog('loadMessages failed: $e');
    }
  }

  // ---- sending ----

  /// Adds an optimistic bubble and sends [text] (queued until ready).
  void send(String text) {
    if (_disposed || text.trim().isEmpty) return;
    final echoId = _uuid.v4();
    _upsertLocal(
      TextMessage(
        id: echoId,
        authorId: _meId,
        text: text,
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.sending,
      ),
    );
    unawaited(_dispatch(echoId, text));
  }

  /// Retries the failed message [key].
  void resend(String key) {
    final m = _byKey[key];
    if (_disposed || m is! TextMessage || m.status != MessageStatus.error) {
      return;
    }
    _upsertLocal(m.copyWith(status: MessageStatus.sending));
    unawaited(_dispatch(key, m.text));
  }

  Future<void> _dispatch(String echoId, String text) async {
    final client = _client;
    if (client == null) {
      if (_error != null) {
        _markFailed(echoId);
      } else {
        _pending[echoId] = text;
      }
      return;
    }
    try {
      await client.sendMessage(content: text, echoId: echoId);
    } catch (e) {
      sdkLog('send failed: $e');
      _markFailed(echoId);
    }
  }

  void _markFailed(String key) {
    final m = _byKey[key];
    if (_disposed || m == null) return;
    _upsertLocal(m.copyWith(status: MessageStatus.error));
  }

  // ---- callbacks ----

  ChatwootCallbacks _wrapCallbacks() {
    // Everything from a disposed controller is dropped.
    T? live<T>(T Function() f) => _disposed ? null : f();
    return ChatwootCallbacks(
      onWelcome: () => live(() => callbacks?.onWelcome?.call()),
      onPing: () => live(() => callbacks?.onPing?.call()),
      onConfirmedSubscription: () =>
          live(() => callbacks?.onConfirmedSubscription?.call()),
      onConnectionStateChanged: (state) =>
          live(() => callbacks?.onConnectionStateChanged?.call(state)),
      onConversationIsOnline: () => live(() {
        _setStatus(ChatwootChatStatus.online);
        callbacks?.onConversationIsOnline?.call();
      }),
      onConversationIsOffline: () => live(() {
        _setStatus(ChatwootChatStatus.offline);
        callbacks?.onConversationIsOffline?.call();
      }),
      onConversationStartedTyping: () => live(() {
        _setStatus(ChatwootChatStatus.typing);
        callbacks?.onConversationStartedTyping?.call();
      }),
      onConversationStoppedTyping: () => live(() {
        if (_status == ChatwootChatStatus.typing) {
          _setStatus(ChatwootChatStatus.online);
        }
        callbacks?.onConversationStoppedTyping?.call();
      }),
      onPersistedMessagesRetrieved: (list) => live(() {
        if (options.enablePersistence) _bulkUpsert(list);
        callbacks?.onPersistedMessagesRetrieved?.call(list);
      }),
      onMessagesRetrieved: (list) => live(() {
        _bulkUpsert(list);
        callbacks?.onMessagesRetrieved?.call(list);
      }),
      onMessageReceived: (m) => live(() {
        _upsertServer(m);
        callbacks?.onMessageReceived?.call(m);
      }),
      onMessageUpdated: (m) => live(() {
        _upsertServer(m, onlyExisting: true);
        callbacks?.onMessageUpdated?.call(m);
      }),
      onMessageSent: (m, echoId) => live(() {
        _confirmEcho(m, echoId, MessageStatus.delivered);
        callbacks?.onMessageSent?.call(m, echoId);
      }),
      onMessageDelivered: (m, echoId) => live(() {
        _confirmEcho(m, echoId, MessageStatus.seen);
        callbacks?.onMessageDelivered?.call(m, echoId);
      }),
      onConversationResolved: () => live(() {
        _addResolved();
        callbacks?.onConversationResolved?.call();
      }),
      onError: (e) => live(() {
        final data = e.data;
        if (e.type == ChatwootClientExceptionType.SEND_MESSAGE_FAILED &&
            data is String) {
          _markFailed(data);
        }
        sdkLog('error: ${e.cause}');
        callbacks?.onError?.call(e);
      }),
    );
  }

  void _setStatus(ChatwootChatStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  // ---- message list ----

  /// Maps a server message; null when it must not be shown.
  Message? _convert(ChatwootMessage m, {String? key}) {
    final type = m.messageType;
    if (type == 2 || type == 3) return null; // activity / template
    final text = (m.content ?? '').trim().isNotEmpty
        ? m.content!
        : (m.attachments?.isNotEmpty ?? false)
        ? l10n.attachmentLabel
        : null;
    if (text == null) return null;
    final String authorId;
    if (type == 1) {
      final sender = m.sender;
      authorId = sender?.id == null ? _agentId : 'agent:${sender!.id}';
      var avatar = sender?.avatarUrl ?? sender?.thumbnail;
      // Server-controlled URL: https only, no 404 placeholder.
      if (avatar != null &&
          (!avatar.startsWith('https://') || avatar.contains('?d=404'))) {
        avatar = null;
      }
      _users[authorId] = User(
        id: authorId,
        name: sender?.name,
        imageSource: avatar,
      );
    } else {
      authorId = _meId;
    }
    key ??= _keyByServerId[m.id] ?? m.id.toString();
    return TextMessage(
      id: key,
      authorId: authorId,
      text: text,
      createdAt:
          DateTime.tryParse(m.createdAt)?.toUtc() ??
          (_byKey[key]?.createdAt ?? DateTime.now().toUtc()),
      status: authorId == _meId ? MessageStatus.seen : null,
    );
  }

  void _upsertServer(ChatwootMessage m, {bool onlyExisting = false}) {
    final converted = _convert(m);
    if (converted == null) return;
    final existing = _byKey[converted.id];
    if (existing == null && onlyExisting) return;
    _upsertLocal(existing == null ? converted : _merge(existing, converted));
  }

  /// Keeps what the local bubble knows better than the server (position and
  /// delivery state), takes the server's text and author.
  Message _merge(Message existing, Message incoming) => incoming.copyWith(
    createdAt: existing.createdAt,
    status: _rank(existing.status) > _rank(incoming.status)
        ? existing.status
        : incoming.status,
  );

  int _rank(MessageStatus? s) => switch (s) {
    MessageStatus.sending || MessageStatus.error => 0,
    MessageStatus.delivered => 1,
    MessageStatus.seen => 2,
    null => 2,
    _ => 1,
  };

  /// The server accepted [echoId] as [m]: alias the ids so later server
  /// events for [m] land on the same bubble.
  void _confirmEcho(ChatwootMessage m, String echoId, MessageStatus status) {
    final serverKey = m.id.toString();
    final echo = _byKey[echoId];
    final duplicate = _keyByServerId[m.id] == null ? _byKey[serverKey] : null;
    _keyByServerId[m.id] = echoId;
    if (duplicate != null) {
      // The socket echo beat the REST response: keep one bubble.
      _byKey.remove(serverKey);
      unawaited(chat.removeMessage(duplicate));
    }
    if (echo == null) {
      final converted = _convert(m, key: echoId);
      if (converted != null) _upsertLocal(converted.copyWith(status: status));
      return;
    }
    _upsertLocal(_merge(echo, echo.copyWith(status: status)));
  }

  void _addResolved() {
    final last = chat.messages.isEmpty ? null : chat.messages.last;
    if (last != null && last.id.startsWith(_resolvedPrefix)) return;
    _users[_systemId] = User(id: _systemId, name: l10n.botName);
    _upsertLocal(
      TextMessage(
        id: '$_resolvedPrefix${_resolvedCount++}',
        authorId: _systemId,
        text: l10n.conversationResolvedMessage,
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.delivered,
      ),
    );
    notifyListeners();
  }

  /// Insert or replace one message without touching the rest of the list.
  void _upsertLocal(Message message) {
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

  void _bulkUpsert(List<ChatwootMessage> list) {
    var changed = false;
    // Oldest first with a numeric id tie-break (shared with storage); new
    // keys are appended in that order, existing ones keep their slot.
    for (final m in sortMessagesOldestFirst(list)) {
      final converted = _convert(m);
      if (converted == null) continue;
      final existing = _byKey[converted.id];
      _byKey[converted.id] = existing == null
          ? converted
          : _merge(existing, converted);
      changed = true;
    }
    if (!changed) return;
    // Stable by time: equal timestamps keep the order established above.
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final ordered = [for (final (i, m) in _byKey.values.indexed) (m, i)]
      ..sort((a, b) {
        final byTime = (a.$1.createdAt ?? epoch).compareTo(
          b.$1.createdAt ?? epoch,
        );
        return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
      });
    unawaited(chat.setMessages([for (final (m, _) in ordered) m]));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final client = _client;
    if (client != null) unawaited(client.dispose());
    chat.dispose();
    super.dispose();
  }
}
