import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/zukko_chat_callbacks.dart';
import '../../core/zukko_chat_client.dart';
import '../../core/zukko_chat_client_exception.dart';
import '../../core/zukko_chat_upload.dart';
import '../../data/models/zukko_chat_message.dart';
import '../../data/models/zukko_chat_user.dart';
import '../../data/message_sync.dart';
import '../../data/models/message_order.dart';
import '../../shared/sdk_log.dart';
import '../../shared/url_policy.dart';
import '../l10n/zukko_chat_l10n.dart';
import 'chat_connection_monitor.dart';
import 'chat_message_mapper.dart';
import 'chat_message_store.dart';
import 'chat_typing.dart';
import 'zukko_chat_options.dart';

/// Signature of [ZukkoChatClient.create]; a custom client (offline demo,
/// tests) is injected through [debugClientFactory]; it is not public API.
typedef ZukkoChatClientFactory = Future<ZukkoChatClient> Function({
  required String baseUrl,
  required String websiteToken,
  ZukkoChatUser? user,
  bool enablePersistence,
  ZukkoChatCallbacks? callbacks,
});

enum ZukkoChatStatus { offline, online, typing }

const _resolvedPrefix = 'zukko-resolved-';

/// Owns the [ZukkoChatClient] lifecycle, the outbox and the callbacks of one
/// chat. The message list is a [ChatMessageStore], server messages are
/// mapped by [ChatMessageMapper].
class ZukkoChatController extends ChangeNotifier {
  ZukkoChatController(
    this.options, {
    this.callbacks,
    ZukkoChatClientFactory clientFactory = ZukkoChatClient.create,
    InMemoryChatController? chat,
    this._probe = resolvesHost,
  }) : _factory = clientFactory,
       _store = ChatMessageStore(chat ?? InMemoryChatController()),
       _mapper = ChatMessageMapper(options.l10n ?? const ZukkoChatL10n()) {
    _typing = OutgoingTyping(_sendTyping);
    _users[chatMeId] = User(
      id: chatMeId,
      name: options.user?.name,
      imageSource: safeAvatarUrl(options.user?.avatarUrl),
    );
    unawaited(_start());
  }

  final ZukkoChatOptions options;
  final ZukkoChatClientFactory _factory;
  final Future<bool> Function(String host) _probe;
  final ChatMessageStore _store;
  final ChatMessageMapper _mapper;

  /// Drives the "no internet / connecting" banner; a drop shorter than two
  /// seconds never shows.
  late final ChatConnectionMonitor connection = ChatConnectionMonitor(
    host: Uri.tryParse(options.baseUrl)?.host ?? '',
    onBackOnline: () => _client?.resume(),
    probe: _probe,
  );
  late final OutgoingTyping _typing;

  /// Consumer callbacks; the view keeps them current across rebuilds.
  ZukkoChatCallbacks? callbacks;

  /// Backing controller of the flutter_chat_ui `Chat` widget.
  InMemoryChatController get chat => _store.chat;

  /// Strings used for generated messages; the view keeps it current.
  ZukkoChatL10n get l10n => _mapper.l10n;
  set l10n(ZukkoChatL10n value) => _mapper.l10n = value;

  final _users = <String, User>{};

  /// What each unconfirmed local message carries (to send and resend), by
  /// echoId; dropped once the server confirms it.
  final _outbox = <String, _Outgoing>{};

  /// EchoIds waiting for the client to exist.
  final _queued = <String>{};
  final _uuid = const Uuid();

  ZukkoChatClient? _client;
  bool _disposed = false;
  bool _visible = true;
  int _resolvedCount = 0;

  // ---- older history (paged on demand) ----

  /// Id of the oldest server message loaded so far: the `before` cursor.
  int? _oldestId;

  /// False once a page came back short: the start of the conversation.
  bool _hasMore = true;
  bool _loadingOlder = false;

  /// The next `onMessagesRetrieved` is the latest page (not a catch-up): a
  /// short one means the conversation has no older messages.
  bool _awaitingLatest = false;

  /// Bumped by [retry]: callbacks of an earlier client are dropped.
  int _generation = 0;
  // Header status inputs. No conversation yet counts as one the AI answers.
  ZukkoChatStatus _status = ZukkoChatStatus.online;
  String? _conversationStatus;
  bool _agentOnline = false;
  bool _agentTyping = false;
  ZukkoChatException? _error;

  String get currentUserId => chatMeId;
  ZukkoChatStatus get status => _status;

  /// True once the client exists; sends before that are queued.
  bool get isReady => _client != null;

  /// Set when the client could not be created.
  ZukkoChatException? get error => _error;

  Future<User> resolveUser(String id) async => _users[id] ?? User(id: id);

  /// The author [id] as known so far (name, avatar); null when unknown.
  User? userById(String id) => _users[id];

  /// Whether the user can see the chat. While it is, incoming agent messages
  /// are marked as read; becoming visible marks what arrived meanwhile.
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    if (value) {
      _markSeen();
      try {
        _client?.resume(); // realtime may have stopped while in background
      } catch (e) {
        sdkLog('resume failed: ${e.runtimeType}');
      }
    }
  }

  /// Tries again after [error]; no-op unless the chat is in an error state.
  void retry() {
    if (_disposed || _error == null) return;
    _error = null;
    _generation++; // the old client may still report: ignore it from now on
    final old = _client;
    _client = null; // a session failure leaves a client that must be replaced
    if (old != null) unawaited(old.dispose());
    notifyListeners();
    unawaited(_start());
  }

  Future<void> _start() async {
    final generation = _generation;
    final ZukkoChatClient client;
    try {
      client = await _factory(
        baseUrl: options.baseUrl,
        websiteToken: options.websiteToken,
        user: options.user,
        enablePersistence: options.enablePersistence,
        callbacks: _wrapCallbacks(generation),
      );
    } catch (e, st) {
      sdkLog('client failed with error $e: $st');
      if (_disposed || generation != _generation) return;
      _error = ZukkoChatException(
        e.toString(),
        ZukkoChatExceptionType.createClientFailed,
      );
      // Nothing will ever send these: show them as failed (tap to retry).
      _queued.toList().forEach(_store.markFailed);
      _queued.clear();
      callbacks?.onError?.call(_error!);
      notifyListeners();
      return;
    }
    if (_disposed || generation != _generation) {
      unawaited(client.dispose());
      return;
    }
    _client = client;
    notifyListeners();
    final queued = _queued.toList();
    _queued.clear();
    for (final echoId in queued) {
      unawaited(_dispatch(echoId));
    }
    _awaitingLatest = true;
    try {
      await client.loadMessages();
    } catch (e) {
      sdkLog('loadMessages failed: $e');
    }
    if (generation != _generation) return; // replaced by retry meanwhile
    _awaitingLatest = false;
    if (_error == null) _markSeen();
  }

  /// Loads the next page of older messages (the user reached the top of the
  /// list). One request at a time; a failure keeps the list and the next call
  /// retries. Never throws.
  Future<void> loadOlder() async {
    final client = _client;
    final before = _oldestId;
    if (_disposed ||
        _loadingOlder ||
        !_hasMore ||
        client == null ||
        before == null) {
      return;
    }
    _loadingOlder = true;
    final generation = _generation;
    try {
      final page = await client.loadOlderMessages(before: before);
      // dropped: disposed, retried, or the session reset meanwhile
      if (_disposed || generation != _generation || _oldestId != before) return;
      if (page == null) return; // failed: the next scroll to the top retries
      _bulkUpsert(page);
      _noteOldest(page);
      _hasMore = page.length >= MessageSync.pageSize;
    } catch (e) {
      sdkLog('loadOlder failed: ${e.runtimeType}');
    } finally {
      _loadingOlder = false;
    }
  }

  void _noteOldest(List<ZukkoChatMessage> page) {
    for (final m in page) {
      if (_oldestId == null || m.id < _oldestId!) _oldestId = m.id;
    }
  }

  /// Best effort: the client never throws here, a fake might.
  void _markSeen() {
    final client = _client;
    if (_disposed || !_visible || client == null) return;
    unawaited(_quiet(client.markSeen()));
  }

  static Future<void> _quiet(Future<void> call) async {
    try {
      await call;
    } catch (e) {
      sdkLog('best-effort call failed: ${e.runtimeType}');
    }
  }

  // ---- typing ----

  void _sendTyping(bool on) {
    final client = _client;
    if (client != null) unawaited(_quiet(client.setTyping(on)));
  }

  /// The composer text changed: tells the agents the user is typing, and that
  /// they stopped after [OutgoingTyping.defaultIdle] without input.
  void typing() {
    if (!_disposed) _typing.ping();
  }

  // ---- sending ----

  /// Adds an optimistic bubble and sends [text] (queued until ready).
  void send(String text) {
    if (_disposed || text.trim().isEmpty) return;
    _typing.stop();
    final echoId = _uuid.v4();
    _outbox[echoId] = _Outgoing(text, const []);
    _store.upsertLocal(
      TextMessage(
        id: echoId,
        authorId: chatMeId,
        text: text,
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.sending,
      ),
    );
    unawaited(_dispatch(echoId));
  }

  /// Sends [files] as one message, shown at once as a local preview (image,
  /// gallery, voice or file). [audioDuration] is the length of a recording.
  void sendAttachments(List<ZukkoChatUpload> files, {Duration? audioDuration}) {
    if (_disposed || files.isEmpty) return;
    _typing.stop();
    final echoId = _uuid.v4();
    _outbox[echoId] = _Outgoing('', List.unmodifiable(files));
    _store.upsertLocal(_mapper.localPreview(echoId, files, audioDuration));
    unawaited(_dispatch(echoId));
  }

  /// Retries the failed message [key].
  void resend(String key) {
    final m = _store[key];
    if (_disposed ||
        m == null ||
        !_outbox.containsKey(key) ||
        m.status != MessageStatus.error) {
      return;
    }
    _store.upsertLocal(m.copyWith(status: MessageStatus.sending));
    unawaited(_dispatch(key));
  }

  Future<void> _dispatch(String echoId) async {
    final outgoing = _outbox[echoId];
    if (outgoing == null) return;
    final client = _client;
    if (client == null) {
      if (_error != null) {
        _fail(echoId);
      } else {
        _queued.add(echoId);
      }
      return;
    }
    try {
      await client.sendMessage(
        content: outgoing.text,
        echoId: echoId,
        attachments: outgoing.attachments,
      );
    } catch (e) {
      sdkLog('send failed: $e');
      _fail(echoId);
    }
  }

  void _fail(String key) {
    if (!_disposed) _store.markFailed(key);
  }

  // ---- callbacks ----

  /// The client's callbacks. Everything from a disposed controller, or from
  /// a client of an earlier [retry] generation, is dropped.
  ZukkoChatCallbacks _wrapCallbacks(int generation) {
    bool live() => !_disposed && generation == _generation;
    void Function() pass(void Function()? Function(ZukkoChatCallbacks) pick) =>
        () {
          final c = callbacks;
          if (live() && c != null) pick(c)?.call();
        };
    // State change first, then the consumer's callback.
    void Function() react(
      void Function() change,
      void Function()? Function(ZukkoChatCallbacks) pick,
    ) => () {
      if (!live()) return;
      change();
      final c = callbacks;
      if (c != null) pick(c)?.call();
    };

    return ZukkoChatCallbacks(
      onWelcome: pass((c) => c.onWelcome),
      onPing: pass((c) => c.onPing),
      onConfirmedSubscription: pass((c) => c.onConfirmedSubscription),
      onConnectionStateChanged: (state) {
        if (!live()) return;
        connection.onState(state);
        callbacks?.onConnectionStateChanged?.call(state);
      },
      onConversationUpdated: (conversation) {
        if (!live()) return;
        _conversationStatus = conversation.status;
        _refreshStatus();
        callbacks?.onConversationUpdated?.call(conversation);
      },
      onConversationIsOnline: react(() {
        _agentOnline = true;
        _refreshStatus();
      }, (c) => c.onConversationIsOnline),
      onConversationIsOffline: react(() {
        _agentOnline = false;
        _refreshStatus();
      }, (c) => c.onConversationIsOffline),
      onConversationStartedTyping: react(() {
        _agentTyping = true;
        _refreshStatus();
      }, (c) => c.onConversationStartedTyping),
      onConversationStoppedTyping: react(() {
        _agentTyping = false;
        _refreshStatus();
      }, (c) => c.onConversationStoppedTyping),
      onConversationResolved: react(
        _addResolved,
        (c) => c.onConversationResolved,
      ),
      onSessionReset: react(() {
        _store.keepOnly(_outbox.containsKey);
        _oldestId = null;
        _hasMore = true;
        _awaitingLatest = true; // the new contact's latest page follows
        _conversationStatus = null;
        _refreshStatus();
      }, (c) => c.onSessionReset),
      onPersistedMessagesRetrieved: (list) {
        if (!live()) return;
        if (options.enablePersistence) _bulkUpsert(list);
        callbacks?.onPersistedMessagesRetrieved?.call(list);
      },
      onMessagesRetrieved: (list) {
        if (!live()) return;
        _bulkUpsert(list);
        _noteOldest(list);
        if (_awaitingLatest) {
          _awaitingLatest = false;
          _hasMore = list.length >= MessageSync.pageSize;
        }
        callbacks?.onMessagesRetrieved?.call(list);
      },
      onMessageReceived: (m) {
        if (!live()) return;
        _upsertServer(m);
        _markSeen();
        callbacks?.onMessageReceived?.call(m);
      },
      onMessageUpdated: (m) {
        if (!live()) return;
        _upsertServer(m, onlyExisting: true);
        callbacks?.onMessageUpdated?.call(m);
      },
      onMessageSent: (m, echoId) {
        if (!live()) return;
        _confirmEcho(m, echoId, MessageStatus.delivered);
        callbacks?.onMessageSent?.call(m, echoId);
      },
      onMessageDelivered: (m, echoId) {
        if (!live()) return;
        _confirmEcho(m, echoId, MessageStatus.seen);
        callbacks?.onMessageDelivered?.call(m, echoId);
      },
      onError: (e) {
        if (!live()) return;
        if (e.type == ZukkoChatExceptionType.invalidIdentifierHash ||
            e.type == ZukkoChatExceptionType.identifyFailed ||
            e.type == ZukkoChatExceptionType.sessionExpired) {
          _error = e;
          notifyListeners();
        }
        final data = e.data;
        // any typed failure of a send (INVALID_IDENTIFIER_HASH, SESSION_EXPIRED,
        // SEND_MESSAGE_FAILED, ...) carries the echoId of its bubble
        if (data is String && _outbox.containsKey(data)) _fail(data);
        sdkLog('error: ${e.cause}');
        callbacks?.onError?.call(e);
      },
    );
  }

  /// Header status: typing wins; otherwise online when the AI answers
  /// (conversation `pending`/`resolved`, or none yet) or an agent is online,
  /// offline for `open`/`snoozed` without an online agent.
  void _refreshStatus() {
    final aiAnswers = switch (_conversationStatus) {
      null || 'pending' || 'resolved' => true,
      _ => false,
    };
    _setStatus(
      _agentTyping
          ? ZukkoChatStatus.typing
          : aiAnswers || _agentOnline
          ? ZukkoChatStatus.online
          : ZukkoChatStatus.offline,
    );
  }

  void _setStatus(ZukkoChatStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  // ---- message list ----

  /// Maps [m] under [key] (default: its list key) and remembers its author.
  Message? _convert(ZukkoChatMessage m, {String? key}) {
    key ??= _store.keyOfServer(m.id);
    final mapped = _mapper.fromServer(
      m,
      key: key,
      fallbackCreatedAt: _store[key]?.createdAt,
    );
    if (mapped == null) return null;
    final author = mapped.author;
    if (author != null) _users[author.id] = author;
    return mapped.message;
  }

  void _upsertServer(ZukkoChatMessage m, {bool onlyExisting = false}) {
    final converted = _convert(m);
    if (converted != null) {
      _store.upsertServer(converted, onlyExisting: onlyExisting);
    }
  }

  /// The server accepted [echoId] as [m]: alias the ids so later server
  /// events for [m] land on the same bubble.
  void _confirmEcho(ZukkoChatMessage m, String echoId, MessageStatus status) {
    final echo = _store[echoId];
    final hadFiles = _outbox.remove(echoId)?.attachments.isNotEmpty ?? false;
    _store.alias(m.id, echoId);
    if (echo == null) {
      final converted = _convert(m, key: echoId);
      if (converted != null) {
        _store.upsertLocal(converted.copyWith(status: status));
      }
      return;
    }
    // A sent attachment: the server's version has the real urls.
    final server = hadFiles ? _convert(m, key: echoId) : null;
    _store.upsertLocal(
      ChatMessageStore.merge(echo, (server ?? echo).copyWith(status: status)),
    );
  }

  void _addResolved() {
    final last = _store.last;
    if (last != null && last.id.startsWith(_resolvedPrefix)) return;
    _users[chatSystemId] = User(id: chatSystemId, name: l10n.botName);
    _store.upsertLocal(
      TextMessage(
        id: '$_resolvedPrefix${_resolvedCount++}',
        authorId: chatSystemId,
        text: l10n.conversationResolvedMessage,
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.delivered,
      ),
    );
  }

  void _bulkUpsert(List<ZukkoChatMessage> list) {
    // Oldest first with a numeric id tie-break (shared with storage).
    final converted = [
      for (final m in sortMessagesOldestFirst(list)) ?_convert(m),
    ];
    _store.bulkUpsert(converted);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final wasTyping = _typing.isOn;
    _typing.dispose();
    final client = _client;
    if (client != null) {
      // tell the agents we stopped typing before the HTTP clients close
      if (wasTyping) {
        unawaited(
          _quiet(client.setTyping(false)).then((_) => client.dispose()),
        );
      } else {
        unawaited(client.dispose());
      }
    }
    connection.dispose();
    chat.dispose();
    super.dispose();
  }
}

/// Text and files of a message sent from this device.
class _Outgoing {
  final String text;
  final List<ZukkoChatUpload> attachments;

  const _Outgoing(this.text, this.attachments);
}
