import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/chatwoot_client_exception.dart';
import '../../../shared/sdk_log.dart';
import 'chatwoot_action_data.dart';
import 'chatwoot_event.dart';
import 'socket_frame.dart';

/// Where the realtime connection currently is.
///
/// {@category FlutterClientSdk}
enum ChatwootConnectionState {
  /// Not started yet.
  idle,

  /// Opening the websocket, waiting for the server's welcome.
  connecting,

  /// Websocket is open, subscription not confirmed yet.
  connected,

  /// Subscribed to the contact's channel: events flow.
  subscribed,

  /// The connection was lost, a new attempt is scheduled.
  backoff,

  /// Disposed, or stopped for good (rejected subscription, server said not to
  /// reconnect). [ChatwootSocket.connect] starts it again.
  closed,
}

sealed class SocketEvent {
  const SocketEvent();
}

class SocketStateChanged extends SocketEvent {
  const SocketStateChanged(this.state, {this.isReconnect = false});

  final ChatwootConnectionState state;

  /// `true` when [state] is `subscribed` and the socket had been subscribed
  /// before (events may have been missed in between).
  final bool isReconnect;
}

class SocketPing extends SocketEvent {
  const SocketPing();
}

class SocketMessage extends SocketEvent {
  const SocketMessage(this.message);

  final ChatwootEventMessage message;
}

class SocketFailure extends SocketEvent {
  const SocketFailure(this.error);

  final ChatwootClientException error;
}

/// `ws(s)://host[/prefix]/cable` for a REST [baseUrl]. Throws [ArgumentError]
/// for any scheme other than http(s) / ws(s).
Uri chatwootCableUri(String baseUrl) {
  final base = Uri.parse(baseUrl);
  final scheme = switch (base.scheme.toLowerCase()) {
    'https' || 'wss' => 'wss',
    'http' || 'ws' => 'ws',
    _ => throw ArgumentError.value(
      baseUrl,
      'baseUrl',
      'unsupported scheme "${base.scheme}"',
    ),
  };
  final segments = base.pathSegments.where((s) => s.isNotEmpty).toList();
  return base.replace(scheme: scheme, pathSegments: [...segments, 'cable']);
}

/// `min(30 s, 1 s * 2^attempt)` plus up to 25 % jitter, capped at 30 s.
Duration defaultSocketBackoff(int attempt, [Random? random]) {
  final base = 1000 * (1 << min(attempt, 5));
  final jitter = (random ?? _random).nextInt(base ~/ 4 + 1);
  return Duration(milliseconds: min(30000, base + jitter));
}

final _random = Random();

/// ActionCable connection of one contact: owns the websocket, the handshake,
/// presence heartbeat, stale-connection detection and reconnecting.
///
/// Pure Dart; the channel factory and the backoff are injectable so everything
/// is testable with fake timers. All outcomes arrive on [events]; nothing
/// here throws.
class ChatwootSocket {
  ChatwootSocket({
    required this.url,
    required this._tokenProvider,
    WebSocketChannel Function(Uri)? connect,
    this.presenceEvery = const Duration(seconds: 15), // server window: 20 s
    this.staleAfter = const Duration(seconds: 6),
    this.connectTimeout = const Duration(seconds: 15),
    this.subscribeTimeout = const Duration(seconds: 10),
    Duration Function(int attempt)? backoff,
  }) : _connect = connect ?? WebSocketChannel.connect,
       _backoff = backoff ?? defaultSocketBackoff;

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

  ChatwootConnectionState _state = ChatwootConnectionState.idle;
  String? _token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _presenceTimer;
  Timer? _watchdog;
  Timer? _retryTimer;
  Timer? _subscribeTimer;
  int _subscribeTimeouts = 0;
  int _attempt = 0;
  bool _wasSubscribed = false;
  bool _disposed = false;

  Stream<SocketEvent> get events => _events.stream;

  ChatwootConnectionState get state => _state;

  String get _identifier =>
      jsonEncode({'channel': 'RoomChannel', 'pubsub_token': _token});

  /// Opens the connection with the current token. Idempotent: a live or
  /// opening connection with the same token is left alone, any other is closed
  /// first, so there is never more than one channel.
  void connect() {
    if (_disposed) return;
    if (_channel != null &&
        _token == _tokenProvider() &&
        (_state == ChatwootConnectionState.subscribed ||
            _state == ChatwootConnectionState.connecting ||
            _state == ChatwootConnectionState.connected)) {
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
  bool send(ChatwootActionType action) {
    if (_state != ChatwootConnectionState.subscribed) return false;
    return _write({
      'command': 'message',
      'identifier': _identifier,
      // ActionCable expects `data` as a JSON string
      'data': jsonEncode({'action': action.wire}),
    });
  }

  /// Closes the connection (code 1000) and the event stream. Late frames and
  /// timers are ignored afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _teardown();
    _state = ChatwootConnectionState.closed;
    await _events.close();
  }

  void _open() {
    _teardown();
    final token = _tokenProvider();
    if (token == null) {
      // no session (yet): nothing to subscribe to
      _token = null;
      _setState(ChatwootConnectionState.closed);
      return;
    }
    _token = token;
    _setState(ChatwootConnectionState.connecting);
    final WebSocketChannel channel;
    try {
      channel = _connect(url);
    } catch (e) {
      sdkLog('socket connect failed: $e');
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
        _setState(ChatwootConnectionState.connected);
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
        final isReconnect = _wasSubscribed;
        _wasSubscribed = true;
        _setState(ChatwootConnectionState.subscribed, isReconnect: isReconnect);
        _startPresence();
      case RejectFrame():
        _rejected();
      case DisconnectFrame(:final reason, :final reconnect):
        if (reconnect) {
          _onLost(channel);
        } else {
          _stop(
            ChatwootClientException(
              'server closed the connection: ${reason ?? 'unknown reason'}',
              ChatwootClientExceptionType.SOCKET_DISCONNECTED,
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
    ChatwootClientException(
      'subscription rejected: unknown or expired pubsub token',
      ChatwootClientExceptionType.SOCKET_SUBSCRIPTION_REJECTED,
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
  void _stop(ChatwootClientException error) {
    _teardown();
    _setState(ChatwootConnectionState.closed);
    _emit(SocketFailure(error));
  }

  void _scheduleRetry() {
    _setState(ChatwootConnectionState.backoff);
    _retryTimer = Timer(_backoff(_attempt++), _open);
  }

  void _startPresence() {
    _presenceTimer?.cancel();
    send(ChatwootActionType.update_presence);
    _presenceTimer = Timer.periodic(presenceEvery, (_) {
      send(ChatwootActionType.update_presence);
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
      sdkLog('socket send failed: $e');
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
      channel.sink.close(1000).ignore();
    } catch (_) {}
  }

  void _setState(ChatwootConnectionState next, {bool isReconnect = false}) {
    if (_state == next) return;
    _state = next;
    _emit(SocketStateChanged(next, isReconnect: isReconnect));
  }

  void _emit(SocketEvent event) {
    if (!_disposed) _events.add(event);
  }
}
