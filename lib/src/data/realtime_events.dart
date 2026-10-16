import 'dart:async';

import '../core/zukko_chat_callbacks.dart';
import '../core/zukko_chat_client_exception.dart';
import '../core/zukko_chat_connection_state.dart';
import '../shared/best_effort.dart';
import '../shared/sdk_log.dart';
import 'local/local_storage.dart';
import 'message_sync.dart';
import 'models/zukko_chat_conversation.dart';
import 'models/zukko_chat_message.dart';
import 'remote/api/widget_session.dart';
import 'remote/realtime/zukko_chat_event.dart';
import 'remote/realtime/zukko_chat_socket.dart';
import 'remote/realtime/zukko_chat_socket_events.dart';
import 'subscription_recovery.dart';

/// Routes what the realtime socket delivers into the app's callbacks and the
/// local storage: messages, conversation changes, typing and presence (with
/// their timers), connection state, and the recovery of a rejected
/// subscription. Nothing here throws.
class RealtimeEvents {
  RealtimeEvents({
    required this._socket,
    required this._storage,
    required this._sync,
    required this._callbacks,
    required WidgetSession? session,
    required this._catchUp,
    required this._reportError,
  }) {
    _recovery = SubscriptionRecovery(
      socket: _socket,
      session: session,
      report: (e) =>
          _reportError(e, ZukkoChatExceptionType.socketSubscriptionRejected),
    );
  }

  /// The server never clears a typing indicator by itself.
  static const _typingTimeout = Duration(seconds: 30);

  /// Presence updates arrive about every 20 s; without one the agent is offline.
  static const _presenceTimeout = Duration(seconds: 40);

  static const _online = 'online';

  final ZukkoChatSocket _socket;
  final LocalStorage _storage;
  final MessageSync _sync;
  final ZukkoChatCallbacks _callbacks;
  final Future<void> Function(int? after) _catchUp;
  final void Function(Object error, ZukkoChatExceptionType fallback)
  _reportError;
  late final SubscriptionRecovery _recovery;

  StreamSubscription<SocketEvent>? _subscription;
  Timer? _typingTimer;
  Timer? _presenceResetTimer;
  bool _disposed = false;

  /// Starts listening and connects. Safe to call repeatedly: there is only ever
  /// one subscription and one connection. Does nothing without a pubsub token.
  void listen() {
    if (_disposed || _storage.contact.get()?.pubsubToken == null) return;
    _subscription ??= _socket.events.listen(_onSocketEvent);
    _socket.connect();
  }

  /// The app is in the foreground again: restart a stopped connection. A
  /// pending subscription rejection is retried instead of connecting blindly.
  void resume() {
    if (_disposed) return;
    if (!_recovery.resume()) listen();
  }

  void _onSocketEvent(SocketEvent event) {
    if (_disposed) return;
    try {
      switch (event) {
        case SocketStateChanged(:final state):
          _onState(state);
        case SocketPing():
          _callbacks.onPing?.call();
        case SocketFailure(:final error):
          if (error.type == ZukkoChatExceptionType.socketSubscriptionRejected) {
            unawaited(_recovery.onRejected(error));
          } else {
            _reportError(error, ZukkoChatExceptionType.socketDisconnected);
          }
        case SocketMessage(:final message):
          _onMessage(message);
      }
    } catch (e, st) {
      // a bad event must never stop the following ones
      sdkLog('socket event failed: ${e.runtimeType}');
      sdkLog('$st');
    }
  }

  void _onState(ZukkoChatConnectionState state) {
    _callbacks.onConnectionStateChanged?.call(state);
    switch (state) {
      case ZukkoChatConnectionState.connected:
        _callbacks.onWelcome?.call();
      case ZukkoChatConnectionState.subscribed:
        _callbacks.onConfirmedSubscription?.call();
        _recovery.onSubscribed();
        // Messages may have arrived before the subscription (first connect) or
        // while we were offline: fetch everything after the newest one received
        // (the latest page if none); ids make the merge idempotent.
        unawaited(_catchUp(_sync.cursor));
      default:
        // without a live connection typing / presence are unknown
        _clearPresence();
        _stopTyping();
    }
  }

  void _onMessage(ZukkoChatEventMessage message) {
    final data = message.data;
    final type = message.event;
    if (data == null || type == null) {
      sdkLog('ignored unknown event');
      return;
    }
    switch (type) {
      case ZukkoChatEventMessageType.messageCreated:
        _onMessageCreated(data);
      case ZukkoChatEventMessageType.messageUpdated:
        _onMessageUpdated(data);
      case ZukkoChatEventMessageType.conversationTypingOn:
        if (data.isPrivate != true) _startTyping();
      case ZukkoChatEventMessageType.conversationTypingOff:
        if (data.isPrivate != true) _stopTyping();
      case ZukkoChatEventMessageType.conversationCreated:
      case ZukkoChatEventMessageType.conversationUpdated:
      case ZukkoChatEventMessageType.conversationStatusChanged:
        _onConversation(type, data);
      case ZukkoChatEventMessageType.presenceUpdate:
        _onPresence(data.users);
    }
  }

  void _onMessageCreated(ZukkoChatEventMessageData data) {
    // activity lines and private notes are not part of the chat
    if (data.private == true ||
        data.messageType == ZukkoChatMessage.typeActivity) {
      return;
    }
    final created = data.toMessage();
    if (!_isOwnConversation(created)) return;
    final echoId = data.echoId;
    if (created.isMine) {
      // our own message (from this device, or another session of the contact)
      // is never "received"; only a confirmed send has an echo to deliver
      if (echoId != null) _callbacks.onMessageDelivered?.call(created, echoId);
    } else if (!_sync.isKnown(created.id)) {
      _stopTyping(); // the agent finished typing
      _callbacks.onMessageReceived?.call(created);
    }
    _sync.noteServer(created);
    unawaited(_sync.save(created));
  }

  void _onMessageUpdated(ZukkoChatEventMessageData data) {
    if (data.private == true) return;
    final updated = data.toMessage();
    if (!_isOwnConversation(updated)) return;
    final known = _sync.find(updated.id);
    if (known != null && MessageSync.changesAuthor(known, updated)) {
      sdkLog('ignored update of message ${updated.id} that changes author');
      return;
    }
    _sync.noteServer(updated);
    _callbacks.onMessageUpdated?.call(updated);
    unawaited(_sync.save(updated));
  }

  /// `conversation.created/updated/status_changed`. Events of the contact's
  /// own inbox only; a new conversation replaces the stored one (the server
  /// shows the contact its latest), updates of another one are ignored. The
  /// messages stay when it is resolved: the contact can keep writing.
  void _onConversation(
    ZukkoChatEventMessageType type,
    ZukkoChatEventMessageData data,
  ) {
    final id = data.id;
    if (id == null || id <= 0) return;
    final stored = _storage.conversation.get();
    final inboxId = data.inboxId ?? stored?.inboxId ?? 0;
    if (stored != null && stored.inboxId > 0 && inboxId != stored.inboxId) {
      return; // another inbox
    }
    final adopt =
        stored == null ||
        (stored.id != id &&
            type == ZukkoChatEventMessageType.conversationCreated);
    if (!adopt && stored.id != id) return;
    final status = data.status ?? (stored?.id == id ? stored?.status : null);
    final conversation = ZukkoChatConversation(
      id: id,
      inboxId: inboxId,
      status: status,
    );
    unawaited(
      bestEffort(
        () => _storage.conversation.save(conversation),
        'persisting the conversation',
      ),
    );
    // `status_changed` and `updated` both announce a resolve: once is enough
    final wasResolved = stored != null && stored.id == id && stored.isResolved;
    if (conversation.isResolved && !wasResolved) {
      _stopTyping();
      _callbacks.onConversationResolved?.call();
    }
    _callbacks.onConversationUpdated?.call(conversation);
  }

  void _onPresence(Object? users) {
    if (users is! Map) return;
    _presenceResetTimer?.cancel();
    if (users.values.contains(_online)) {
      _callbacks.onConversationIsOnline?.call();
      _presenceResetTimer = Timer(_presenceTimeout, () {
        _presenceResetTimer = null;
        _callbacks.onConversationIsOffline?.call();
      });
    } else {
      _presenceResetTimer = null;
      _callbacks.onConversationIsOffline?.call();
    }
  }

  void _clearPresence() {
    _presenceResetTimer?.cancel();
    _presenceResetTimer = null;
  }

  void _startTyping() {
    if (_typingTimer == null) _callbacks.onConversationStartedTyping?.call();
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, _stopTyping);
  }

  /// Fires the stop callback only when typing was shown.
  void _stopTyping() {
    final timer = _typingTimer;
    if (timer == null) return;
    timer.cancel();
    _typingTimer = null;
    _callbacks.onConversationStoppedTyping?.call();
  }

  /// Events of other conversations (or with a bogus id) are not ours.
  bool _isOwnConversation(ZukkoChatMessage message) =>
      message.id > 0 &&
      message.conversationId != null &&
      message.conversationId == _storage.conversation.get()?.id;

  /// Cancels timers and the subscription; nothing is delivered afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _typingTimer?.cancel();
    _presenceResetTimer?.cancel();
    _recovery.dispose();
    _subscription?.cancel().ignore(); // our own broadcast stream: sync
    _subscription = null;
  }
}
