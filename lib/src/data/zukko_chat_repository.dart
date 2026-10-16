import 'dart:async';

import '../core/zukko_chat_callbacks.dart';
import '../core/zukko_chat_client_exception.dart';
import '../core/zukko_chat_connection_state.dart';
import '../core/zukko_chat_upload.dart';
import '../shared/best_effort.dart';
import '../shared/safe_invoke.dart';
import '../shared/sdk_log.dart';
import '../shared/trailing_throttle.dart';
import 'local/local_storage.dart';
import 'message_sync.dart';
import 'models/zukko_chat_conversation.dart';
import 'models/zukko_chat_message.dart';
import 'realtime_events.dart';
import 'remote/api/requests/zukko_chat_new_message_request.dart';
import 'remote/api/widget_session.dart';
import 'remote/api/zukko_chat_client_service.dart';
import 'remote/realtime/zukko_chat_action_data.dart';
import 'remote/realtime/zukko_chat_socket.dart';

/// Handles interactions between the Zukko Chat client api service and the local
/// storage (if persistence is enabled). Results are passed through the client's
/// [ZukkoChatCallbacks], never returned.
abstract interface class ZukkoChatRepository {
  /// Establishes the session, refreshes the conversation, then starts the
  /// realtime link. Never throws: failures go to `onError`.
  Future<void> initialize();

  /// Reports the newest persisted messages (one page, not the whole cache).
  void getPersistedMessages();

  /// The page of messages just older than message id [before], oldest first;
  /// fewer than a page means there are no more. Not persisted, not reported
  /// through the callbacks. Returns null on failure (reported through
  /// `onError`). Never throws.
  Future<List<ZukkoChatMessage>?> getOlderMessages(int before);

  /// Fetches messages: the latest page, or with [after] everything newer than
  /// that message id. Never throws.
  Future<void> getMessages({int? after});

  void listenForEvents();

  Future<void> sendMessage(
    ZukkoChatNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  });

  /// Returns whether the action was sent (`false` while not subscribed).
  bool sendAction(ZukkoChatActionType action);

  /// Tells agents the contact started / stopped typing. Never throws.
  Future<void> setTyping(bool on);

  /// Marks the agents' messages as read. Never throws.
  Future<void> markSeen();

  /// The app is in the foreground again: restart realtime if it stopped.
  void resume();

  Future<void> clear({bool clearContact = true});

  Future<void> dispose();
}

class ZukkoChatRepositoryImpl implements ZukkoChatRepository {
  ZukkoChatRepositoryImpl({
    required ZukkoChatClientService clientService,
    required LocalStorage localStorage,
    required ZukkoChatCallbacks streamCallbacks,
    required this._socket,
    WidgetSession? session,
  }) : _clientService = clientService,
       _storage = localStorage,
       _callbacks = streamCallbacks,
       _session = session {
    _sync = MessageSync(clientService, localStorage);
    _realtime = RealtimeEvents(
      socket: _socket,
      storage: localStorage,
      sync: _sync,
      callbacks: streamCallbacks,
      session: session,
      catchUp: (after) => getMessages(after: after),
      reportError: _emitError,
    );
    _markSeen = TrailingThrottle(
      _seenEvery,
      () => bestEffort(_clientService.updateLastSeen, 'marking seen'),
    );
    session?.listener = SessionListener(
      onReset: _onSessionReset,
      onReady: _onSessionReady,
      onError: (e) => _emitError(e, e.type),
    );
  }

  /// At most one last-seen request per this long.
  static const _seenEvery = Duration(seconds: 2);

  final ZukkoChatClientService _clientService;
  final LocalStorage _storage;
  final ZukkoChatCallbacks _callbacks;
  final ZukkoChatSocket _socket;
  final WidgetSession? _session;
  late final MessageSync _sync;
  late final RealtimeEvents _realtime;
  late final TrailingThrottle _markSeen;
  bool _disposed = false;

  /// `initialize` is running: it loads and connects after the session is up,
  /// so session events during it must not do that too. Later ones (a late first
  /// start, a rebuild) bring the realtime link up themselves.
  bool _initializing = false;

  /// Fetches the latest messages, or with [after] everything newer than that
  /// message id.
  ///
  /// Calls [ZukkoChatCallbacks.onMessagesRetrieved] when the fetch is successful
  /// Calls [ZukkoChatCallbacks.onError] for every failure; never throws.
  @override
  Future<void> getMessages({int? after}) async {
    try {
      final messages = await _sync.fetch(after: after);
      if (!_disposed) _callbacks.onMessagesRetrieved?.call(messages);
    } catch (e) {
      _emitError(e, ZukkoChatExceptionType.getMessagesFailed);
    }
  }

  @override
  Future<List<ZukkoChatMessage>?> getOlderMessages(int before) async {
    try {
      return await _sync.fetchBefore(before);
    } catch (e) {
      _emitError(e, ZukkoChatExceptionType.getMessagesFailed);
      return null;
    }
  }

  /// Fetches the newest persisted messages (one page: older ones are loaded
  /// from the server on demand and are not stored).
  ///
  /// Calls [ZukkoChatCallbacks.onPersistedMessagesRetrieved] if persisted messages are found
  @override
  void getPersistedMessages() {
    final all = _storage.messages.getMessages(); // oldest first
    final persisted = all.length > MessageSync.pageSize
        ? all.sublist(all.length - MessageSync.pageSize)
        : all;
    if (persisted.isNotEmpty) {
      _callbacks.onPersistedMessagesRetrieved?.call(persisted);
    }
  }

  /// Establishes the widget session, refreshes the conversation, then starts
  /// listening for events. A rejected identifier hash fails closed: no
  /// conversation fetch and no realtime.
  ///
  /// Never throws: every failure is reported through [ZukkoChatCallbacks.onError].
  @override
  Future<void> initialize() async {
    _initializing = true;
    try {
      await _session?.start();
      await _syncConversation();
    } catch (e) {
      _emitError(e, ZukkoChatExceptionType.createClientFailed);
    }
    _initializing = false;

    // A session that is not usable (identifier hash rejected, set_user or
    // /config failed) gets no realtime link; the session's `onReady` brings it
    // up once a later start succeeds.
    if (_session?.isReady == false) return;
    listenForEvents();
  }

  /// A start that failed during `initialize` succeeded later: the missing
  /// conversation sync and realtime link follow.
  void _onSessionReady() {
    if (_disposed || _initializing) return;
    unawaited(_syncConversationSafely().then((_) => listenForEvents()));
  }

  /// The session was reset (new contact, new pubsub token): tell the UI to
  /// drop the old contact's messages, follow with the realtime connection and
  /// load the new contact's conversation and latest messages.
  void _onSessionReset() {
    if (_disposed) return;
    _sync.reset(); // messages of the previous contact are gone
    _callbacks.onSessionReset?.call();
    if (_initializing) return; // `initialize` loads and connects afterwards
    _socket.reconnectIfTokenChanged();
    unawaited(_syncConversationSafely().then((_) => getMessages()));
  }

  /// Stores the contact's current conversation (if it has one). Another one
  /// than the stored one means the stored messages are not its own.
  Future<void> _syncConversation() async {
    final conversation = await _clientService.getConversation();
    if (conversation == null) return;
    final persisted = _storage.conversation.get();
    if (persisted != null && persisted.id != conversation.id) {
      _sync.forgetKnown();
      await _storage.messages.clear();
    }
    await _storage.conversation.save(conversation);
    if (!_disposed) _callbacks.onConversationUpdated?.call(conversation);
  }

  /// [_syncConversation] for callers that go on regardless: a failure is
  /// reported (`GET_CONVERSATION_FAILED`), never thrown.
  Future<void> _syncConversationSafely() async {
    try {
      await _syncConversation();
    } catch (e) {
      _emitError(e, ZukkoChatExceptionType.getConversationFailed);
    }
  }

  /// Reports [error] through `onError`, typed [fallback] unless it already is a
  /// [ZukkoChatException]. A throwing host callback is swallowed; nothing is
  /// reported after dispose.
  void _emitError(
    Object error,
    ZukkoChatExceptionType fallback, {
    Object? data,
  }) {
    // A rejected identity hash already got its one ERROR line in the session.
    final loggedAsError =
        error is ZukkoChatException &&
        error.type == ZukkoChatExceptionType.invalidIdentifierHash;
    if (!loggedAsError) {
      sdkLog('$fallback: ${error.runtimeType}', level: SdkLogLevel.warning);
    }
    final cb = _callbacks.onError;
    if (cb == null || _disposed) return;
    final typed = error is ZukkoChatException
        ? error
        : ZukkoChatException(error.toString(), fallback, error: error);
    final reported = data == null
        ? typed
        : ZukkoChatException(
            typed.cause,
            typed.type,
            data: data,
            error: typed.error,
            stackTrace: typed.stackTrace,
          );
    safeInvoke(() => cb(reported), 'onError');
  }

  /// Sends a message, with [attachments] as one multipart message.
  @override
  Future<void> sendMessage(
    ZukkoChatNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  }) async {
    final ZukkoChatMessage createdMessage;
    try {
      createdMessage = await _clientService.createMessage(
        request,
        attachments: attachments,
      );
    } catch (e) {
      // anything may fail here; the UI bubble waits for this echoId
      _emitError(
        e,
        ZukkoChatExceptionType.sendMessageFailed,
        data: request.echoId,
      );
      return;
    }
    _sync.remember(createdMessage); // not the cursor: see [MessageSync.cursor]
    await _rememberConversation(createdMessage.conversationId);
    await _sync.save(createdMessage);
    if (!_disposed) {
      _callbacks.onMessageSent?.call(createdMessage, request.echoId);
    }
  }

  /// The first message creates the conversation on the server: remember it, so
  /// realtime events of it are recognised as ours.
  Future<void> _rememberConversation(int? id) async {
    if (id == null || id <= 0) return;
    final current = _storage.conversation.get();
    if (current?.id == id) return;
    await bestEffort(
      () => _storage.conversation.save(
        ZukkoChatConversation(id: id, inboxId: current?.inboxId ?? 0),
      ),
      'persisting the conversation',
    );
  }

  /// Connects to the realtime socket and starts listening for updates. Safe to
  /// call repeatedly: there is only ever one connection.
  ///
  /// Received events/messages are pushed through the callbacks.
  @override
  void listenForEvents() {
    if (!_disposed) _realtime.listen();
  }

  @override
  void resume() {
    if (_disposed || _initializing) return;
    if (_socket.state == ZukkoChatConnectionState.backoff) {
      _socket.retryNow(); // do not wait out the backoff
      return;
    }
    if (_socket.state != ZukkoChatConnectionState.closed) return;
    if (_session?.isReady == false || _session?.failure != null) return;
    _realtime.resume();
  }

  /// Clears this instance's conversation and messages; the contact too unless
  /// [clearContact] is false.
  @override
  Future<void> clear({bool clearContact = true}) {
    _sync.forgetKnown();
    return _storage.clear(clearContact: clearContact);
  }

  /// Stops the realtime link and the timers; nothing reaches the app
  /// afterwards. Safe to call more than once. Persisted data stays.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _markSeen.dispose();
    _realtime.dispose();
    await _socket.dispose();
  }

  ///Send actions like user started typing
  @override
  bool sendAction(ZukkoChatActionType action) => _socket.send(action);

  /// Best effort (a 404 without a conversation is normal): failures are logged.
  @override
  Future<void> setTyping(bool on) =>
      bestEffort(() => _clientService.toggleTyping(on), 'typing');

  /// At most one request per [_seenEvery]; calls inside the window collapse
  /// into one trailing request.
  @override
  Future<void> markSeen() => _markSeen();
}
