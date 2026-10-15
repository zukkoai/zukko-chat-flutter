import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:uuid/uuid.dart';

import '../../core/chatwoot_callbacks.dart';
import '../../core/chatwoot_client.dart';
import '../../core/chatwoot_client_exception.dart';
import '../../core/chatwoot_upload.dart';
import '../../data/models/chatwoot_message.dart';
import '../../data/models/chatwoot_user.dart';
import '../../shared/message_order.dart';
import '../../shared/sdk_log.dart';
import '../l10n/chatwoot_l10n.dart';
import 'chatwoot_chat_options.dart';
import 'components/gallery_message.dart';

/// Signature of [ZukkoChatClient.create]; the seam tests use to inject a fake.
typedef ZukkoChatClientFactory = Future<ZukkoChatClient> Function({
  required String baseUrl,
  required String websiteToken,
  ZukkoChatUser? user,
  bool enablePersistence,
  bool allowInsecure,
  ZukkoChatCallbacks? callbacks,
});

enum ZukkoChatStatus { offline, online, typing }

const _meId = 'chatwoot-me';
const _agentId = 'chatwoot-agent';
const _systemId = 'chatwoot-system';
const _resolvedPrefix = 'chatwoot-resolved-';

/// Without input for this long the user counts as not typing any more.
const typingIdle = Duration(seconds: 3);

/// Owns the [ZukkoChatClient] lifecycle and the message list of one chat.
///
/// Messages live in [chat] (oldest first) under a stable key: the client's
/// `echoId` for messages sent from here, the server id otherwise. Once the
/// server confirms a sent message its id is aliased to the echo key, so the
/// server's own `message.created` echo updates the same bubble instead of
/// adding a second one. Single events use `insertMessage`/`updateMessage`;
/// only bulk loads use `setMessages`.
class ZukkoChatController extends ChangeNotifier {
  ZukkoChatController(
    this.options, {
    this.callbacks,
    ZukkoChatClientFactory clientFactory = ZukkoChatClient.create,
    InMemoryChatController? chat,
  }) : _factory = clientFactory,
       chat = chat ?? InMemoryChatController(),
       l10n = options.l10n ?? const ZukkoChatL10n() {
    _users[_meId] = User(
      id: _meId,
      name: options.user?.name,
      imageSource: options.user?.avatarUrl,
    );
    unawaited(_start());
  }

  final ZukkoChatOptions options;
  final ZukkoChatClientFactory _factory;

  /// Consumer callbacks; the view keeps them current across rebuilds.
  ZukkoChatCallbacks? callbacks;

  /// Backing controller of the flutter_chat_ui `Chat` widget.
  final InMemoryChatController chat;

  /// Strings used for generated messages; the view keeps it current.
  ZukkoChatL10n l10n;

  final _users = <String, User>{};
  final _byKey = <String, Message>{};
  final _keyByServerId = <int, String>{};

  /// What each unconfirmed local message carries (to send and resend), by
  /// echoId; dropped once the server confirms it.
  final _outbox = <String, _Outgoing>{};

  /// EchoIds waiting for the client to exist.
  final _queued = <String>{};
  final _uuid = const Uuid();

  ZukkoChatClient? _client;
  bool _disposed = false;
  bool _visible = true;
  bool _typingOn = false;
  Timer? _typingIdle;
  int _resolvedCount = 0;
  ZukkoChatStatus _status = ZukkoChatStatus.offline;
  ZukkoChatException? _error;

  String get currentUserId => _meId;
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
    final old = _client;
    _client = null; // a session failure leaves a client that must be replaced
    if (old != null) unawaited(old.dispose());
    notifyListeners();
    unawaited(_start());
  }

  Future<void> _start() async {
    final ZukkoChatClient client;
    try {
      client = await _factory(
        baseUrl: options.baseUrl,
        websiteToken: options.websiteToken,
        user: options.user,
        enablePersistence: options.enablePersistence,
        allowInsecure: options.allowInsecure,
        callbacks: _wrapCallbacks(),
      );
    } catch (e, st) {
      sdkLog('client failed with error $e: $st');
      if (_disposed) return;
      _error = ZukkoChatException(
        e.toString(),
        ZukkoChatExceptionType.CREATE_CLIENT_FAILED,
      );
      // Nothing will ever send these: show them as failed (tap to retry).
      _queued.toList().forEach(_markFailed);
      _queued.clear();
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
    final queued = _queued.toList();
    _queued.clear();
    for (final echoId in queued) {
      unawaited(_dispatch(echoId));
    }
    try {
      await client.loadMessages();
    } catch (e) {
      sdkLog('loadMessages failed: $e');
    }
    if (_error == null) _markSeen();
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

  /// The composer text changed: tells the agents the user is typing, and that
  /// they stopped after [typingIdle] without input.
  void typing() {
    if (_disposed) return;
    if (!_typingOn) {
      _typingOn = true;
      final client = _client;
      if (client != null) unawaited(_quiet(client.setTyping(true)));
    }
    _typingIdle?.cancel();
    _typingIdle = Timer(typingIdle, _typingOff);
  }

  void _typingOff() {
    _typingIdle?.cancel();
    _typingIdle = null;
    if (!_typingOn) return;
    _typingOn = false;
    final client = _client;
    if (client != null) unawaited(_quiet(client.setTyping(false)));
  }

  // ---- sending ----

  /// Adds an optimistic bubble and sends [text] (queued until ready).
  void send(String text) {
    if (_disposed || text.trim().isEmpty) return;
    _typingOff();
    final echoId = _uuid.v4();
    _outbox[echoId] = _Outgoing(text, const []);
    _upsertLocal(
      TextMessage(
        id: echoId,
        authorId: _meId,
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
    _typingOff();
    final echoId = _uuid.v4();
    _outbox[echoId] = _Outgoing('', List.unmodifiable(files));
    _upsertLocal(_localPreview(echoId, files, audioDuration));
    unawaited(_dispatch(echoId));
  }

  Message _localPreview(
    String id,
    List<ZukkoChatUpload> files,
    Duration? audioDuration,
  ) {
    final createdAt = DateTime.now().toUtc();
    const status = MessageStatus.sending;
    // A local path shows the image before the upload ends; the web has none.
    final first = files.first;
    if (files.length > 1 && files.every((f) => f.isImage)) {
      return GalleryMessage.create(
        id: id,
        authorId: _meId,
        images: [for (final f in files) f.path ?? ''],
        createdAt: createdAt,
        status: status,
      );
    }
    if (first.isImage) {
      return ImageMessage(
        id: id,
        authorId: _meId,
        source: first.path ?? '',
        createdAt: createdAt,
        status: status,
      );
    }
    if (first.isAudio) {
      return AudioMessage(
        id: id,
        authorId: _meId,
        source: first.path ?? '',
        duration: audioDuration ?? Duration.zero,
        size: first.size,
        createdAt: createdAt,
        status: status,
      );
    }
    return FileMessage(
      id: id,
      authorId: _meId,
      source: first.path ?? '',
      name: first.name,
      size: first.size,
      createdAt: createdAt,
      status: status,
    );
  }

  /// Retries the failed message [key].
  void resend(String key) {
    final m = _byKey[key];
    if (_disposed ||
        m == null ||
        !_outbox.containsKey(key) ||
        m.status != MessageStatus.error) {
      return;
    }
    _upsertLocal(m.copyWith(status: MessageStatus.sending));
    unawaited(_dispatch(key));
  }

  Future<void> _dispatch(String echoId) async {
    final outgoing = _outbox[echoId];
    if (outgoing == null) return;
    final client = _client;
    if (client == null) {
      if (_error != null) {
        _markFailed(echoId);
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
      _markFailed(echoId);
    }
  }

  void _markFailed(String key) {
    final m = _byKey[key];
    if (_disposed || m == null) return;
    _upsertLocal(m.copyWith(status: MessageStatus.error));
  }

  // ---- callbacks ----

  ZukkoChatCallbacks _wrapCallbacks() {
    // Everything from a disposed controller is dropped.
    T? live<T>(T Function() f) => _disposed ? null : f();
    return ZukkoChatCallbacks(
      onWelcome: () => live(() => callbacks?.onWelcome?.call()),
      onPing: () => live(() => callbacks?.onPing?.call()),
      onConfirmedSubscription: () =>
          live(() => callbacks?.onConfirmedSubscription?.call()),
      onConnectionStateChanged: (state) =>
          live(() => callbacks?.onConnectionStateChanged?.call(state)),
      onConversationIsOnline: () => live(() {
        _setStatus(ZukkoChatStatus.online);
        callbacks?.onConversationIsOnline?.call();
      }),
      onConversationIsOffline: () => live(() {
        _setStatus(ZukkoChatStatus.offline);
        callbacks?.onConversationIsOffline?.call();
      }),
      onConversationStartedTyping: () => live(() {
        _setStatus(ZukkoChatStatus.typing);
        callbacks?.onConversationStartedTyping?.call();
      }),
      onConversationStoppedTyping: () => live(() {
        if (_status == ZukkoChatStatus.typing) {
          _setStatus(ZukkoChatStatus.online);
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
        _markSeen();
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
      onSessionReset: () => live(() {
        _dropServerMessages();
        callbacks?.onSessionReset?.call();
      }),
      onError: (e) => live(() {
        if (e.type == ZukkoChatExceptionType.INVALID_IDENTIFIER_HASH ||
            e.type == ZukkoChatExceptionType.IDENTIFY_FAILED ||
            e.type == ZukkoChatExceptionType.SESSION_EXPIRED) {
          _error = e;
          notifyListeners();
        }
        final data = e.data;
        // any typed failure of a send (INVALID_IDENTIFIER_HASH, SESSION_EXPIRED,
        // SEND_MESSAGE_FAILED, ...) carries the echoId of its bubble
        if (data is String && _outbox.containsKey(data)) _markFailed(data);
        sdkLog('error: ${e.cause}');
        callbacks?.onError?.call(e);
      }),
    );
  }

  /// The session now belongs to another contact: nothing the server sent so
  /// far may stay on screen. Messages still waiting to be sent are kept.
  void _dropServerMessages() {
    final unsent = [
      for (final m in chat.messages)
        if (_outbox.containsKey(m.id)) m,
    ];
    _byKey
      ..clear()
      ..addEntries([for (final m in unsent) MapEntry(m.id, m)]);
    _keyByServerId.clear();
    unawaited(chat.setMessages(unsent));
  }

  void _setStatus(ZukkoChatStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  // ---- message list ----

  /// Maps a server message; null when it must not be shown.
  ///
  /// Attachments with an https url become an image, a gallery (several
  /// images), an audio or a file message, with the text as caption; others
  /// fall back to a text message with [ZukkoChatL10n.attachmentLabel].
  Message? _convert(ZukkoChatMessage m, {String? key}) {
    final type = m.messageType;
    if (type == 2 || type == 3) return null; // activity / template
    final content = (m.content ?? '').trim().isNotEmpty ? m.content : null;
    final attachments = [
      for (final raw in m.attachments ?? const <dynamic>[])
        ?_Attachment.tryParse(raw),
    ];
    final hasAttachments = m.attachments?.isNotEmpty ?? false;
    if (content == null && !hasAttachments) return null;
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
    final createdAt =
        DateTime.tryParse(m.createdAt)?.toUtc() ??
        (_byKey[key]?.createdAt ?? DateTime.now().toUtc());
    final status = authorId == _meId ? MessageStatus.seen : null;

    final images = [
      for (final a in attachments)
        if (a.kind == _AttachmentKind.image) a.url,
    ];
    if (images.length > 1) {
      return GalleryMessage.create(
        id: key,
        authorId: authorId,
        images: images,
        caption: content,
        createdAt: createdAt,
        status: status,
      );
    }
    if (images.length == 1) {
      return ImageMessage(
        id: key,
        authorId: authorId,
        source: images.single,
        text: content,
        createdAt: createdAt,
        status: status,
      );
    }
    final first = attachments.firstOrNull;
    if (first != null && first.kind == _AttachmentKind.audio) {
      return AudioMessage(
        id: key,
        authorId: authorId,
        source: first.url,
        duration: Duration.zero,
        text: content,
        size: first.size,
        createdAt: createdAt,
        status: status,
      );
    }
    if (first != null) {
      return FileMessage(
        id: key,
        authorId: authorId,
        source: first.url,
        name: first.name ?? l10n.attachmentLabel,
        size: first.size,
        createdAt: createdAt,
        status: status,
      );
    }
    return TextMessage(
      id: key,
      authorId: authorId,
      text: content ?? l10n.attachmentLabel,
      createdAt: createdAt,
      status: status,
    );
  }

  void _upsertServer(ZukkoChatMessage m, {bool onlyExisting = false}) {
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
  void _confirmEcho(ZukkoChatMessage m, String echoId, MessageStatus status) {
    final serverKey = m.id.toString();
    final echo = _byKey[echoId];
    final hadFiles = _outbox.remove(echoId)?.attachments.isNotEmpty ?? false;
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
    // A sent attachment: the server's version has the real urls.
    final server = hadFiles ? _convert(m, key: echoId) : null;
    _upsertLocal(_merge(echo, (server ?? echo).copyWith(status: status)));
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

  void _bulkUpsert(List<ZukkoChatMessage> list) {
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
    _typingIdle?.cancel();
    final client = _client;
    if (client != null) {
      // tell the agents we stopped typing before the HTTP clients close
      if (_typingOn) {
        unawaited(
          _quiet(client.setTyping(false)).then((_) => client.dispose()),
        );
      } else {
        unawaited(client.dispose());
      }
    }
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

enum _AttachmentKind { image, audio, file }

/// One entry of a Chatwoot message's `attachments` (`file_type`,
/// `data_url`, `file_size`).
class _Attachment {
  final _AttachmentKind kind;
  final String url;
  final String? name;
  final int? size;

  const _Attachment(this.kind, this.url, this.name, this.size);

  /// Null unless [raw] is a map with an https `data_url`.
  static _Attachment? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['data_url'];
    if (url is! String || !url.startsWith('https://')) return null;
    final size = raw['file_size'];
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    return _Attachment(
      switch (raw['file_type']) {
        'image' => _AttachmentKind.image,
        'audio' => _AttachmentKind.audio,
        _ => _AttachmentKind.file,
      },
      url,
      segments.isEmpty ? null : segments.last,
      size is int ? size : null,
    );
  }
}
