import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/zukko_chat_connection_state.dart';

/// What the connection banner says.
enum ChatConnectionNotice { none, offline, connecting }

/// Whether [host] can be resolved: our own backend, no third-party host, no
/// plugin and no extra permission.
// ponytail: a cached DNS answer can read "online" for a while; swap in a
// connectivity plugin only if that proves a problem.
Future<bool> resolvesHost(String host) async {
  // no dart:io sockets on web, no host to test: never claim "offline"
  if (kIsWeb || host.isEmpty) return true;
  try {
    final found = await InternetAddress.lookup(host)
        .timeout(const Duration(seconds: 3));
    return found.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Turns the realtime connection state into the banner: nothing while
/// subscribed or within [showAfter] of a drop (and during the first
/// connect), then "offline" (the backend host does not resolve) or
/// "connecting". While down it re-checks every [recheckEvery] and calls
/// [onBackOnline] the moment the host resolves again, to skip the backoff.
class ChatConnectionMonitor extends ChangeNotifier {
  ChatConnectionMonitor({
    required this.host,
    required this.onBackOnline,
    this._probe = resolvesHost,
    this.showAfter = const Duration(seconds: 2),
    this.recheckEvery = const Duration(seconds: 3),
  });

  final String host;
  final void Function() onBackOnline;
  final Future<bool> Function(String host) _probe;
  final Duration showAfter;
  final Duration recheckEvery;

  ChatConnectionNotice _notice = ChatConnectionNotice.none;
  ChatConnectionNotice get notice => _notice;

  bool _down = false;

  /// Bumped on every down/up transition: a probe that was already running
  /// when the state flipped must not start a second recheck loop.
  int _epoch = 0;
  bool _disposed = false;
  Timer? _timer;

  void onState(ZukkoChatConnectionState state) {
    if (_disposed) return;
    switch (state) {
      case ZukkoChatConnectionState.subscribed:
      case ZukkoChatConnectionState.closed: // stopped on purpose, not a drop
        _down = false;
        _epoch++;
        _timer?.cancel();
        _set(ChatConnectionNotice.none);
      case ZukkoChatConnectionState.idle:
      case ZukkoChatConnectionState.connecting:
      case ZukkoChatConnectionState.connected:
      case ZukkoChatConnectionState.backoff:
        if (_down) return;
        _down = true;
        _epoch++;
        _timer?.cancel();
        _timer = Timer(showAfter, _check);
    }
  }

  Future<void> _check() async {
    final epoch = _epoch;
    final online = await _probe(host);
    if (_disposed || !_down || epoch != _epoch) return;
    final wasOffline = _notice == ChatConnectionNotice.offline;
    _set(
      online ? ChatConnectionNotice.connecting : ChatConnectionNotice.offline,
    );
    _timer = Timer(recheckEvery, _check); // before the callback: it may throw
    if (online && wasOffline) {
      try {
        onBackOnline();
      } catch (_) {
        // a failing resume must not stop the rechecks
      }
    }
  }

  void _set(ChatConnectionNotice next) {
    if (_notice == next) return;
    _notice = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
