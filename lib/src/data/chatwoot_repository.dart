import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/chatwoot_callbacks.dart';
import '../core/chatwoot_client_exception.dart';
import '../core/chatwoot_upload.dart';
import '../shared/sdk_log.dart';
import 'local/local_storage.dart';
import 'models/chatwoot_message.dart';
import 'models/chatwoot_user.dart';
import 'remote/api/chatwoot_client_service.dart';
import 'remote/api/requests/chatwoot_new_message_request.dart';
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

  Future<void> getMessages();

  void listenForEvents();

  Future<void> sendMessage(
    ChatwootNewMessageRequest request, {
    List<ChatwootUpload> attachments = const [],
  });

  /// Returns whether the action was sent (`false` while not subscribed).
  bool sendAction(ChatwootActionType action);

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
  }) : super(clientService, localStorage, streamCallbacks);

  final ChatwootSocket _socket;
  StreamSubscription<SocketEvent>? _socketSubscription;
  Timer? _typingTimer;
  Timer? _presenceResetTimer;
  bool _disposed = false;

  /// Messages seen in this process, by id. Persisting is not awaited on the
  /// live path, so storage can lag behind: duplicate detection and the
  /// author check on updates go through this map first.
  final _known = <int, ChatwootMessage>{};

  /// Fetches the latest messages.
  ///
  /// Calls [ChatwootCallbacks.onMessagesRetrieved] when [ChatwootClientService.getAllMessages] is successful
  /// Calls [ChatwootCallbacks.onError] for every failure; never throws.
  @override
  Future<void> getMessages() async {
    try {
      final messages = await clientService.getAllMessages();
      for (final m in messages) {
        _known[m.id] = m;
      }
      await _persist(localStorage.messages.saveAllMessages(messages));
      callbacks.onMessagesRetrieved?.call(messages);
    } catch (e) {
      _emitError(e, ChatwootClientExceptionType.GET_MESSAGES_FAILED);
    }
  }

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

  /// Initializes chatwoot client repository: refreshes the contact and
  /// conversation, then starts listening for events.
  ///
  /// Never throws: every failure is reported through [ChatwootCallbacks.onError].
  @override
  Future<void> initialize(ChatwootUser? user) async {
    try {
      if (user != null) {
        await localStorage.user.save(user);
      }

      //refresh contact
      final contact = await clientService.getContact();
      await localStorage.contact.save(contact);

      //refresh conversation
      final conversations = await clientService.getConversations();
      final persistedConversation = localStorage.conversation.get();
      if (persistedConversation == null) {
        throw ChatwootClientException(
          "no conversation available",
          ChatwootClientExceptionType.GET_CONVERSATION_FAILED,
        );
      }
      final refreshedConversation = conversations.firstWhere(
        (element) => element.id == persistedConversation.id,
        orElse: () => persistedConversation, //highly unlikely orElse will be called but still added it just in case
      );
      await localStorage.conversation.save(refreshedConversation);
    } catch (e) {
      _emitError(e, ChatwootClientExceptionType.CREATE_CLIENT_FAILED);
    }

    listenForEvents();
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

  /// The session was reset (new contact, new pubsub token): follow it.
  void onSessionReset() {
    if (!_disposed) _socket.reconnectIfTokenChanged();
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
      createdMessage = attachments.isEmpty
          ? await clientService.createMessage(request)
          : await clientService.createMessageWithAttachments(
              request,
              attachments,
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
    _known[createdMessage.id] = createdMessage;
    await _persist(localStorage.messages.saveMessage(createdMessage));
    callbacks.onMessageSent?.call(createdMessage, request.echoId);
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
          _emitError(error, ChatwootClientExceptionType.SOCKET_DISCONNECTED);
        case SocketMessage(:final message):
          _onMessage(message);
      }
    } catch (e) {
      // a bad event must never stop the following ones
      sdkLog('socket event failed: $e');
    }
  }

  void _onState(SocketStateChanged event) {
    callbacks.onConnectionStateChanged?.call(event.state);
    switch (event.state) {
      case ChatwootConnectionState.connected:
        callbacks.onWelcome?.call();
      case ChatwootConnectionState.subscribed:
        callbacks.onConfirmedSubscription?.call();
        // Messages may have arrived while we were offline. The public API only
        // pages backwards (`before`), so refetch the latest page; ids make the
        // merge idempotent.
        if (event.isReconnect) {
          unawaited(
            getMessages().catchError((Object e) => sdkLog('refetch: $e')),
          );
        }
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
        _known[created.id] = created;
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
        _known[updated.id] = updated;
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
      case ChatwootEventMessageType.conversation_status_changed:
        if (data.status == "resolved" &&
            data.id == (localStorage.conversation.get()?.id ?? 0)) {
          _stopTyping();
          unawaited(_persist(localStorage.conversation.delete()));
          unawaited(_persist(localStorage.messages.clear()));
          _known.clear();
          callbacks.onConversationResolved?.call();
        }
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
    _socketSubscription?.cancel().ignore(); // our own broadcast stream: sync
    _socketSubscription = null;
    await _socket.dispose();
    await localStorage.dispose();
  }

  ///Send actions like user started typing
  @override
  bool sendAction(ChatwootActionType action) => _socket.send(action);
}
