import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/zukko_chat_client_exception.dart';
import '../../../core/zukko_chat_connection_state.dart';
import '../../../shared/sdk_log.dart';
import 'zukko_chat_action_data.dart';
import 'socket_frame.dart';
import 'zukko_chat_socket_events.dart';
import '../../../shared/backoff.dart';

/// ActionCable connection of one contact: owns the websocket, the handshake,
/// presence heartbeat, stale-connection detection and reconnecting.
///
/// Pure Dart; the channel factory and the backoff are injectable so everything
/// is testable with fake timers. All outcomes arrive on [events]; nothing
/// here throws.
class ZukkoChatSocket {
  ZukkoChatSocket({
    required this.url,
    required this._tokenProvider,
    WebSocketChannel Function(Uri)? connect,
    this.presenceEvery = defaultPresenceEvery,
    this.staleAfter = defaultStaleAfter,
    this.connectTimeout = defaultConnectTimeout,
    Duration? subscribeTimeout,
    Duration Function(int attempt)? backoff,
  }) : subscribeTimeout = subscribeTimeout ?? defaultSubscribeTimeout,
       _connect = connect ?? WebSocketChannel.connect,
       _backoff = backoff ?? defaultSocketBackoff;

  /// The server drops a connection without presence for 20 s.
  static const defaultPresenceEvery = Duration(seconds: 15);

  /// The server pings every 3 s.
  static const defaultStaleAfter = Duration(seconds: 6);
  static const defaultConnectTimeout = Duration(seconds: 15);
  static const defaultSubscribeTimeout = Duration(seconds: 10);

  /// Normal closure.
  static const _closeNormal = 1000;

  final Uri url;
  final Duration presenceEvery;

  /// A connection that delivered no frame (the server pings every 3 s) for this
  /// long is considered dead.
  final Duration staleAfter;

  /// How long a new connection may take to deliver its first frame.
  final Duration connectTimeout;

  /// How long a welcomed connection may wait for `confirm_subscription`. A
  /// dead pubsub token most likely yields silence, not a reject frame: the 1st
  /// timeout reconnects, the 2nd in a row stops like a rejected subscription.
  final Duration subscribeTimeout;

  /// Read on every (re)connect, so a new session's pubsub token is picked up.
  final String? Function() _tokenProvider;
  final WebSocketChannel Function(Uri) _connect;
  final Duration Function(int attempt) _backoff;
  final _events = StreamController<SocketEvent>.broadcast();

  ZukkoChatConnectionState _state = ZukkoChatConnectionState.idle;
  String? _token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _presenceTimer;
  Timer? _watchdog;
  Timer? _retryTimer;
  Timer? _subscribeTimer;
  int _subscribeTimeouts = 0;
  int _attempt = 0;
  bool _disposed = false;

  Stream<SocketEvent> get events => _events.stream;

  ZukkoChatConnectionState get state => _state;

  String get _identifier =>
      jsonEncode({'channel': 'RoomChannel', 'pubsub_token': _token});

  /// Opens the connection with the current token. Idempotent: a live or
  /// opening connection with the same token is left alone, any other is closed
  /// first, so there is never more than one channel.
  void connect() {
    if (_disposed) return;
    if (_channel != null &&
        _token == _tokenProvider() &&
        (_state == ZukkoChatConnectionState.subscribed ||
            _state == ZukkoChatConnectionState.connecting ||
            _state == ZukkoChatConnectionState.connected)) {
      return;
    }
    _attempt = 0;
    _subscribeTimeouts = 0;
    _open();
  }

  /// Reconnects when the session was reset and now has another token (the old
  /// one subscribes to a dead channel). A no-op while the token is unchanged.
  void reconnectIfTokenChanged() {
    if (_disposed) return;
    final token = _tokenProvider();
    if (token != null && token != _token) connect();
  }

  /// Sends [action] to the channel. Returns `false` (and never throws) when
  /// the socket is not subscribed.
  bool send(ZukkoChatActionType action) {
    if (_state != ZukkoChatConnectionState.subscribed) return false;
    return _write({
      'command': 'message',
      'identifier': _identifier,
      // ActionCable expects `data` as a JSON string
      'data': jsonEncode({'action': action.wire}),
    });
  }

  /// Closes the connection (normal closure) and the event stream. Late frames and
  /// timers are ignored afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _teardown();
    _state = ZukkoChatConnectionState.closed;
    await _events.close();
  }

  void _open() {
    _teardown();
    final token = _tokenProvider();
    if (token == null) {
      // no session (yet): nothing to subscribe to
      _token = null;
      _setState(ZukkoChatConnectionState.closed);
      return;
    }
    _token = token;
    _setState(ZukkoChatConnectionState.connecting);
    final WebSocketChannel channel;
    try {
      channel = _connect(url);
    } catch (e) {
      sdkLog('socket connect failed: ${e.runtimeType}');
      _scheduleRetry();
      return;
    }
    _channel = channel;
    // a failed handshake also fails `ready`; the stream error handles it
    channel.ready.then((_) {}, onError: (_) {});
    _subscription = channel.stream.listen(
      (data) => _onData(channel, data),
      onError: (Object _) => _onLost(channel),
      onDone: () => _onLost(channel),
      cancelOnError: false,
    );
    _armWatchdog(connectTimeout);
  }

  void _onData(WebSocketChannel channel, Object? data) {
    if (_disposed || channel != _channel) return;
    _armWatchdog(staleAfter);
    switch (Frame.parse(data)) {
      case WelcomeFrame():
        _setState(ZukkoChatConnectionState.connected);
        _write({'command': 'subscribe', 'identifier': _identifier});
        _subscribeTimer?.cancel();
        _subscribeTimer = Timer(
          subscribeTimeout,
          () => _onSubscribeTimeout(channel),
        );
      case PingFrame():
        _emit(const SocketPing());
      case ConfirmFrame():
        _attempt = 0;
        _subscribeTimeouts = 0;
        _subscribeTimer?.cancel();
        _setState(ZukkoChatConnectionState.subscribed);
        _startPresence();
      case RejectFrame():
        _rejected();
      case DisconnectFrame(:final reason, :final reconnect):
        if (reconnect) {
          _onLost(channel);
        } else {
          _stop(
            ZukkoChatException(
              'server closed the connection: ${reason ?? 'unknown reason'}',
              ZukkoChatExceptionType.SOCKET_DISCONNECTED,
            ),
          );
        }
      case EventFrame(:final message):
        _emit(SocketMessage(message));
      case UnknownFrame():
        sdkLog('ignored unknown socket frame');
    }
  }

  void _rejected() => _stop(
    ZukkoChatException(
      'subscription rejected: unknown or expired pubsub token',
      ZukkoChatExceptionType.SOCKET_SUBSCRIPTION_REJECTED,
    ),
  );

  void _onSubscribeTimeout(WebSocketChannel channel) {
    if (_disposed || channel != _channel) return;
    if (++_subscribeTimeouts >= 2) {
      _rejected();
    } else {
      _teardown();
      _scheduleRetry();
    }
  }

  void _onLost(WebSocketChannel channel) {
    if (_disposed || channel != _channel) return;
    _teardown();
    _scheduleRetry();
  }

  /// Gives up until [connect] is called again.
  void _stop(ZukkoChatException error) {
    _teardown();
    _setState(ZukkoChatConnectionState.closed);
    _emit(SocketFailure(error));
  }

  void _scheduleRetry() {
    _setState(ZukkoChatConnectionState.backoff);
    _retryTimer = Timer(_backoff(_attempt++), _open);
  }

  void _startPresence() {
    _presenceTimer?.cancel();
    send(ZukkoChatActionType.update_presence);
    _presenceTimer = Timer.periodic(presenceEvery, (_) {
      send(ZukkoChatActionType.update_presence);
    });
  }

  void _armWatchdog(Duration timeout) {
    _watchdog?.cancel();
    final channel = _channel;
    if (channel == null) return;
    _watchdog = Timer(timeout, () => _onLost(channel));
  }

  bool _write(Map<String, Object?> frame) {
    final channel = _channel;
    if (channel == null) return false;
    try {
      channel.sink.add(jsonEncode(frame));
      return true;
    } catch (e) {
      sdkLog('socket send failed: ${e.runtimeType}');
      return false;
    }
  }

  /// The one place that releases the channel and every timer.
  void _teardown() {
    _subscription?.cancel().ignore();
    _subscription = null;
    _presenceTimer?.cancel();
    _watchdog?.cancel();
    _retryTimer?.cancel();
    _subscribeTimer?.cancel();
    _presenceTimer = _watchdog = _retryTimer = _subscribeTimer = null;
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      channel.sink.close(_closeNormal).ignore();
    } catch (e) {
      sdkLog('socket close failed: ${e.runtimeType}');
    }
  }

  void _setState(ZukkoChatConnectionState next) {
    if (_state == next) return;
    _state = next;
    _emit(SocketStateChanged(next));
  }

  void _emit(SocketEvent event) {
    if (!_disposed) _events.add(event);
  }
}
