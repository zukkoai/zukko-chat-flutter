import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/chatwoot_callbacks.dart';
import '../core/chatwoot_client_exception.dart';
import '../core/chatwoot_upload.dart';
import '../shared/sdk_log.dart';
import 'local/local_storage.dart';
import 'models/chatwoot_conversation.dart';
import 'models/chatwoot_message.dart';
import 'models/chatwoot_user.dart';
import 'remote/api/chatwoot_client_service.dart';
import 'remote/api/requests/chatwoot_new_message_request.dart';
import 'remote/api/widget_session.dart';
import 'remote/realtime/chatwoot_action_data.dart';
import 'remote/realtime/chatwoot_event.dart';
import 'remote/realtime/chatwoot_socket.dart';

/// Handles interactions between chatwoot client api service[clientService] and
/// [localStorage] if persistence is enabled.
///
/// Results from repository operations are passed through [callbacks] to be handled
/// appropriately
abstract class ChatwootRepository {
  @protected
  final ChatwootClientService clientService;
  @protected
  final LocalStorage localStorage;
  @protected
  ChatwootCallbacks callbacks;

  ChatwootRepository(this.clientService, this.localStorage, this.callbacks);

  Future<void> initialize(ChatwootUser? user);

  void getPersistedMessages();

  /// Fetches messages: the latest page, or with [after] everything newer than
  /// that message id.
  Future<void> getMessages({int? after});

  void listenForEvents();

  Future<void> sendMessage(
    ChatwootNewMessageRequest request, {
    List<ChatwootUpload> attachments = const [],
  });

  /// Returns whether the action was sent (`false` while not subscribed).
  bool sendAction(ChatwootActionType action);

  /// Tells agents the contact started / stopped typing. Never throws.
  Future<void> setTyping(bool on);

  /// Marks the agents' messages as read. Never throws.
  Future<void> markSeen();

  /// The app is in the foreground again: restart realtime if it stopped.
  void resume() {}

  Future<void> clear({bool clearChatwootUserStorage = true});

  Future<void> dispose();
}

/// The server never clears a typing indicator by itself.
const typingTimeout = Duration(seconds: 30);

/// Presence updates arrive about every 20 s; without one the agent is offline.
const presenceTimeout = Duration(seconds: 40);

class ChatwootRepositoryImpl extends ChatwootRepository {
  ChatwootRepositoryImpl({
    required ChatwootClientService clientService,
    required LocalStorage localStorage,
    required ChatwootCallbacks streamCallbacks,
    required this._socket,
    this._session,
  }) : super(clientService, localStorage, streamCallbacks);

  final ChatwootSocket _socket;
  final WidgetSession? _session;
  StreamSubscription<SocketEvent>? _socketSubscription;
  Timer? _typingTimer;
  Timer? _presenceResetTimer;
  bool _disposed = false;

  /// `initialize` is running: it loads and connects after the session is up,
  /// so session events during it must not do that too. Later ones (a late first
  /// start, a rebuild) bring the realtime link up themselves.
  bool _initializing = false;

  /// Highest message id received from a fetch or a socket event; null if none.
  /// Ids returned by our own REST sends never move it: a send can return an id
  /// above messages we have not received yet, and the reconnect refetch
  /// (`after=cursor`) would skip them.
  int? _cursor;

  /// The last rejected subscription, while realtime waits for a slow retry.
  ChatwootClientException? _lastRejected;
  Timer? _rejectedRetry;
  int _rejectedAttempts = 0;
  ChatwootClientExceptionType? _reportedRejection;

  Timer? _seenCooldown;
  bool _seenPending = false;

  /// Messages seen in this process, by id. Persisting is not awaited on the
  /// live path, so storage can lag behind: duplicate detection and the
  /// author check on updates go through this map first.
  final _known = <int, ChatwootMessage>{};

  /// Upper bound of [_known]; the oldest entries go first (storage still
  /// answers for them).
  static const _knownCap = 2000;

  /// Pages fetched at most by one `after` catch-up (100 messages each).
  static const _maxAfterPages = 20;

  void _remember(ChatwootMessage m) {
    _known[m.id] = m;
    while (_known.length > _knownCap) {
      _known.remove(_known.keys.first);
    }
  }

  /// A message that came from the server (fetch or event): moves the cursor.
  void _noteServer(ChatwootMessage m) {
    _remember(m);
    if (m.id > (_cursor ?? 0)) _cursor = m.id;
  }

  /// Fetches the latest messages, or with [after] everything newer than that
  /// message id (pages of up to 100 until the server has no more).
  ///
  /// Calls [ChatwootCallbacks.onMessagesRetrieved] when the fetch is successful
  /// Calls [ChatwootCallbacks.onError] for every failure; never throws.
  @override
  Future<void> getMessages({int? after}) async {
    try {
      final messages = <ChatwootMessage>[];
      if (after == null) {
        messages.addAll(await clientService.getMessages());
      } else {
        var cursor = after;
        for (var pages = 0; pages < _maxAfterPages; pages++) {
          final page = await clientService.getMessages(after: cursor);
          messages.addAll(page);
          final newest = page.fold(cursor, (m, e) => e.id > m ? e.id : m);
          // the server caps a page at 100: ask again from the newest id
          if (page.length < _afterPageSize || newest == cursor) break;
          cursor = newest;
        }
      }
      messages.forEach(_noteServer);
      await _persist(localStorage.messages.saveAllMessages(messages));
      callbacks.onMessagesRetrieved?.call(messages);
    } catch (e) {
      _emitError(e, ChatwootClientExceptionType.GET_MESSAGES_FAILED);
    }
  }

  static const _afterPageSize = 100;

  /// Fetches persisted messages.
  ///
  /// Calls [ChatwootCallbacks.onPersistedMessagesRetrieved] if persisted messages are found
  @override
  void getPersistedMessages() {
    final persistedMessages = localStorage.messages.getMessages();
    if (persistedMessages.isNotEmpty) {
      callbacks.onPersistedMessagesRetrieved?.call(persistedMessages);
    }
  }

  /// Initializes chatwoot client repository: establishes the widget session,
  /// refreshes the conversation, then starts listening for events. A rejected
  /// identifier hash fails closed: no conversation fetch and no realtime.
  ///
  /// Never throws: every failure is reported through [ChatwootCallbacks.onError].
  @override
  Future<void> initialize(ChatwootUser? user) async {
    _initializing = true;
    try {
      if (user != null) {
        await localStorage.user.save(user);
      }
      await _session?.start();
      await _syncConversation();
    } catch (e) {
      _emitError(e, ChatwootClientExceptionType.CREATE_CLIENT_FAILED);
    }
    _initializing = false;

    // A session that is not usable (identifier hash rejected, set_user or
    // /config failed) gets no realtime link; `onSessionReady` brings it up
    // once a later start succeeds.
    if (_session?.isReady == false) return;
    listenForEvents();
  }

  /// A start that failed during `initialize` succeeded later: the missing
  /// conversation sync and realtime link follow.
  void onSessionReady() {
    if (_disposed || _initializing) return;
    unawaited(_afterLateStart());
  }

  Future<void> _afterLateStart() async {
    try {
      await _syncConversation();
    } catch (e) {
      _emitError(e, ChatwootClientExceptionType.GET_CONVERSATION_FAILED);
    }
    if (!_disposed) listenForEvents();
  }

  /// Stores the contact's current conversation (if it has one). Another one
  /// than the stored one means the stored messages are not its own.
  Future<void> _syncConversation() async {
    final conversation = await clientService.getConversation();
    if (conversation == null) return;
    final persisted = localStorage.conversation.get();
    if (persisted != null && persisted.id != conversation.id) {
      _known.clear();
      await localStorage.messages.clear();
    }
    await localStorage.conversation.save(conversation);
  }

  /// Reports [error] through `onError`, typed [fallback] unless it already is a
  /// [ChatwootClientException]. A throwing host callback is swallowed.
  void _emitError(
    Object error,
    ChatwootClientExceptionType fallback, {
    Object? data,
  }) {
    sdkLog('$fallback: $error');
    final typed = error is ChatwootClientException
        ? error
        : ChatwootClientException(error.toString(), fallback);
    try {
      callbacks.onError?.call(
        data == null
            ? typed
            : ChatwootClientException(typed.cause, typed.type, data: data),
      );
    } catch (e) {
      sdkLog('onError callback threw: $e');
    }
  }

  /// Reports a problem the session found on its own (`IDENTIFY_FAILED`).
  void reportError(ChatwootClientException error) {
    if (!_disposed) _emitError(error, error.type);
  }

  /// The session was reset (new contact, new pubsub token): tell the UI to
  /// drop the old contact's messages, follow with the realtime connection and
  /// load the new contact's conversation and latest messages.
  void onSessionReset() {
    if (_disposed) return;
    _known.clear(); // messages of the previous contact are gone
    _cursor = null;
    callbacks.onSessionReset?.call();
    if (_initializing) return; // `initialize` loads and connects afterwards
    _socket.reconnectIfTokenChanged();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      await _syncConversation();
    } catch (e) {
      _emitError(e, ChatwootClientExceptionType.GET_CONVERSATION_FAILED);
    }
    if (!_disposed) await getMessages();
  }

  String? get _pubsubToken => localStorage.contact.get()?.pubsubToken;

  ///Sends message to chatwoot inbox, with [attachments] as one multipart
  ///message.
  @override
  Future<void> sendMessage(
    ChatwootNewMessageRequest request, {
    List<ChatwootUpload> attachments = const [],
  }) async {
    final ChatwootMessage createdMessage;
    try {
      createdMessage = await clientService.createMessage(
        request,
        attachments: attachments,
      );
    } catch (e) {
      // anything may fail here; the UI bubble waits for this echoId
      _emitError(
        e,
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
        data: request.echoId,
      );
      return;
    }
    _remember(createdMessage); // not the cursor: see [_cursor]
    await _rememberConversation(createdMessage.conversationId);
    await _persist(localStorage.messages.saveMessage(createdMessage));
    callbacks.onMessageSent?.call(createdMessage, request.echoId);
  }

  /// The first message creates the conversation on the server: remember it, so
  /// realtime events of it are recognised as ours.
  Future<void> _rememberConversation(int? id) async {
    if (id == null || id <= 0) return;
    final current = localStorage.conversation.get();
    if (current?.id == id) return;
    await _persist(
      localStorage.conversation.save(
        ChatwootConversation(id: id, inboxId: current?.inboxId ?? 0),
      ),
    );
  }

  /// Connects to the chatwoot websocket and starts listening for updates.
  /// Safe to call repeatedly: there is only ever one connection.
  ///
  /// Received events/messages are pushed through [callbacks].
  @override
  void listenForEvents() {
    final token = _pubsubToken;
    if (token == null || _disposed) return;
    _socketSubscription ??= _socket.events.listen(_onSocketEvent);
    _socket.connect();
  }

  void _onSocketEvent(SocketEvent event) {
    if (_disposed) return;
    try {
      switch (event) {
        case SocketStateChanged():
          _onState(event);
        case SocketPing():
          callbacks.onPing?.call();
        case SocketFailure(:final error):
          if (error.type ==
              ChatwootClientExceptionType.SOCKET_SUBSCRIPTION_REJECTED) {
            unawaited(_onSubscriptionRejected(error));
          } else {
            _emitError(error, ChatwootClientExceptionType.SOCKET_DISCONNECTED);
          }
        case SocketMessage(:final message):
          _onMessage(message);
      }
    } catch (e) {
      // a bad event must never stop the following ones
      sdkLog('socket event failed: $e');
    }
  }

  /// The pubsub token was refused: read it again. A new token reconnects; the
  /// same one (or an exhausted refresh budget) leaves the socket closed, reports
  /// the failure once and tries again later (see [_scheduleRejectedRetry]).
  Future<void> _onSubscriptionRejected(ChatwootClientException error) async {
    final session = _session;
    _lastRejected = error;
    var failure = error;
    try {
      if (session != null &&
          await session.refresh(SessionRefreshReason.socketRejected)) {
        // the reset already reconnects; this covers a reset without a change
        if (!_disposed && _socket.state == ChatwootConnectionState.closed) {
          _socket.connect();
        }
        return;
      }
    } catch (e) {
      failure = e is ChatwootClientException ? e : error;
    }
    if (_disposed) return;
    if (_reportedRejection != failure.type) {
      _reportedRejection = failure.type; // once per kind until subscribed
      _emitError(
        failure,
        ChatwootClientExceptionType.SOCKET_SUBSCRIPTION_REJECTED,
      );
    }
    _scheduleRejectedRetry();
  }

  /// A rejection with an unchanged token must not end realtime for good (the
  /// server may have been briefly inconsistent): retry after 60 s, 120 s ...
  /// up to 10 min. Stops on dispose and when the session failed closed.
  void _scheduleRejectedRetry() {
    if (_disposed || _session?.failure != null) return;
    final delay = Duration(seconds: min(600, 60 << min(_rejectedAttempts, 4)));
    _rejectedAttempts++;
    _rejectedRetry?.cancel();
    _rejectedRetry = Timer(delay, () {
      _rejectedRetry = null;
      final last = _lastRejected;
      if (_disposed || last == null) return;
      if (_socket.state != ChatwootConnectionState.closed) return;
      unawaited(_onSubscriptionRejected(last));
    });
  }

  @override
  void resume() {
    if (_disposed || _initializing) return;
    if (_socket.state != ChatwootConnectionState.closed) return;
    if (_session?.isReady == false || _session?.failure != null) return;
    _rejectedRetry?.cancel();
    _rejectedRetry = null;
    final last = _lastRejected;
    if (last != null) {
      unawaited(_onSubscriptionRejected(last));
    } else {
      listenForEvents();
    }
  }

  void _onState(SocketStateChanged event) {
    callbacks.onConnectionStateChanged?.call(event.state);
    switch (event.state) {
      case ChatwootConnectionState.connected:
        callbacks.onWelcome?.call();
      case ChatwootConnectionState.subscribed:
        callbacks.onConfirmedSubscription?.call();
        _lastRejected = null;
        _rejectedAttempts = 0;
        _reportedRejection = null;
        _rejectedRetry?.cancel();
        _rejectedRetry = null;
        // Messages may have arrived before the subscription (first connect) or
        // while we were offline: fetch everything after the newest one received
        // (the latest page if none); ids make the merge idempotent.
        unawaited(
          getMessages(after: _cursor)
              .catchError((Object e) => sdkLog('refetch: $e')),
        );
      default:
        // without a live connection typing / presence are unknown
        _presenceResetTimer?.cancel();
        _presenceResetTimer = null;
        _stopTyping();
    }
  }

  void _onMessage(ChatwootEventMessage message) {
    final data = message.data;
    if (data == null) return;
    switch (message.event) {
      case ChatwootEventMessageType.message_created:
        // activity (2) and private notes are not part of the chat
        if (data.private == true || data.messageType == 2) return;
        final created = data.getMessage();
        if (!_isOwnConversation(created)) return;
        final echoId = data.echoId;
        if (created.isMine && echoId != null) {
          callbacks.onMessageDelivered?.call(created, echoId);
        } else if (!_isKnown(created.id)) {
          _stopTyping(); // the agent finished typing
          callbacks.onMessageReceived?.call(created);
        }
        _noteServer(created);
        unawaited(_persist(localStorage.messages.saveMessage(created)));
      case ChatwootEventMessageType.message_updated:
        if (data.private == true) return;
        final updated = data.getMessage();
        if (!_isOwnConversation(updated)) return;
        final known =
            _known[updated.id] ?? localStorage.messages.getMessage(updated.id);
        // an update edits a message, it must not change who wrote it
        if (known != null && _changesAuthor(known, updated)) {
          sdkLog('ignored update of message ${updated.id} that changes author');
          return;
        }
        _noteServer(updated);
        callbacks.onMessageUpdated?.call(updated);
        unawaited(_persist(localStorage.messages.saveMessage(updated)));
      case ChatwootEventMessageType.conversation_typing_on:
        if (data.isPrivate == true) return;
        if (_typingTimer == null) callbacks.onConversationStartedTyping?.call();
        _typingTimer?.cancel();
        _typingTimer = Timer(typingTimeout, _stopTyping);
      case ChatwootEventMessageType.conversation_typing_off:
        if (data.isPrivate == true) return;
        _typingTimer?.cancel();
        _typingTimer = null;
        callbacks.onConversationStoppedTyping?.call();
      case ChatwootEventMessageType.conversation_created:
      case ChatwootEventMessageType.conversation_updated:
      case ChatwootEventMessageType.conversation_status_changed:
        _onConversation(message.event!, data);
      case ChatwootEventMessageType.presence_update:
        final users = data.users;
        if (users is! Map) return;
        _presenceResetTimer?.cancel();
        if (users.values.contains("online")) {
          callbacks.onConversationIsOnline?.call();
          _presenceResetTimer = Timer(presenceTimeout, () {
            _presenceResetTimer = null;
            callbacks.onConversationIsOffline?.call();
          });
        } else {
          _presenceResetTimer = null;
          callbacks.onConversationIsOffline?.call();
        }
      case null:
        sdkLog('ignored unknown event');
    }
  }

  /// `conversation.created/updated/status_changed`. Events of the contact's
  /// own inbox only; a new conversation replaces the stored one (the server
  /// shows the contact its latest), updates of another one are ignored. The
  /// messages stay when it is resolved: the contact can keep writing.
  void _onConversation(
    ChatwootEventMessageType type,
    ChatwootEventMessageData data,
  ) {
    final id = data.id;
    if (id == null || id <= 0) return;
    final stored = localStorage.conversation.get();
    final inboxId = data.inboxId ?? stored?.inboxId ?? 0;
    if (stored != null && stored.inboxId > 0 && inboxId != stored.inboxId) {
      return; // another inbox
    }
    final adopt =
        stored == null ||
        (stored.id != id &&
            type == ChatwootEventMessageType.conversation_created);
    if (!adopt && stored.id != id) return;
    final status = data.status ?? (stored?.id == id ? stored?.status : null);
    final conversation = ChatwootConversation(
      id: id,
      inboxId: inboxId,
      status: status,
    );
    unawaited(_persist(localStorage.conversation.save(conversation)));
    // `status_changed` and `updated` both announce a resolve: once is enough
    final wasResolved = stored?.id == id && stored?.status == 'resolved';
    if (status == 'resolved' && !wasResolved) {
      _stopTyping();
      callbacks.onConversationResolved?.call();
    }
    callbacks.onConversationUpdated?.call(conversation);
  }

  /// Events of other conversations (or with a bogus id) are not ours.
  bool _isOwnConversation(ChatwootMessage message) =>
      message.id > 0 &&
      message.conversationId != null &&
      message.conversationId == localStorage.conversation.get()?.id;

  bool _isKnown(int id) =>
      _known.containsKey(id) || localStorage.messages.getMessage(id) != null;

  static bool _changesAuthor(ChatwootMessage known, ChatwootMessage updated) {
    final knownSender = known.sender?.id;
    return (known.messageType != null &&
            known.messageType != updated.messageType) ||
        (knownSender != null && knownSender != updated.sender?.id);
  }

  void _stopTyping() {
    if (_typingTimer == null) return;
    _typingTimer!.cancel();
    _typingTimer = null;
    callbacks.onConversationStoppedTyping?.call();
  }

  /// Persisting must never break the live flow: failures are only logged.
  Future<void> _persist(Future<void> write) =>
      write.catchError((Object e) => sdkLog('persisting failed: $e'));

  /// Clears data related to the current chatwoot client instance. The contact
  /// and user are kept unless [clearChatwootUserStorage] is true.
  @override
  Future<void> clear({bool clearChatwootUserStorage = true}) {
    _known.clear();
    return localStorage.clear(
      clearChatwootUserStorage: clearChatwootUserStorage,
    );
  }

  /// Closes the websocket, cancels timers and disposes [localStorage] (in that
  /// order, so no late frame writes to disposed storage). Safe to call more
  /// than once.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // responses still in flight must not reach the app
    callbacks = ChatwootCallbacks();
    _typingTimer?.cancel();
    _presenceResetTimer?.cancel();
    _rejectedRetry?.cancel();
    _seenCooldown?.cancel();
    _socketSubscription?.cancel().ignore(); // our own broadcast stream: sync
    _socketSubscription = null;
    await _socket.dispose();
    await localStorage.dispose();
  }

  ///Send actions like user started typing
  @override
  bool sendAction(ChatwootActionType action) => _socket.send(action);

  @override
  Future<void> setTyping(bool on) =>
      clientService.toggleTyping(on).catchError(_ignore);

  /// At most one request per [_seenEvery]; calls inside the window collapse
  /// into one trailing request.
  @override
  Future<void> markSeen() {
    if (_seenCooldown != null) {
      _seenPending = true;
      return Future.value();
    }
    _seenCooldown = Timer(_seenEvery, () {
      _seenCooldown = null;
      if (_seenPending && !_disposed) {
        _seenPending = false;
        unawaited(markSeen());
      }
    });
    return clientService.updateLastSeen().catchError(_ignore);
  }

  static const _seenEvery = Duration(seconds: 2);

  /// Typing and last-seen are best effort (a 404 without a conversation is
  /// normal): log and move on.
  void _ignore(Object e) => sdkLog('best-effort call failed: ${e.runtimeType}');
}
