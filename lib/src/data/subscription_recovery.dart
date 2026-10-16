import 'dart:async';

import '../core/zukko_chat_client_exception.dart';
import '../core/zukko_chat_connection_state.dart';
import '../shared/backoff.dart';
import 'remote/api/widget_session.dart';
import 'remote/realtime/zukko_chat_socket.dart';

/// Recovers from a rejected realtime subscription: re-reads the pubsub token
/// (a new one reconnects), and when that does not help reports the failure
/// once and retries slowly, so a briefly inconsistent server does not end
/// realtime for good.
class SubscriptionRecovery {
  SubscriptionRecovery({
    required this._socket,
    required this._session,
    required this._report,
  });

  static const _retryBase = Duration(seconds: 60);
  static const _retryMax = Duration(minutes: 10);

  final ZukkoChatSocket _socket;
  final WidgetSession? _session;
  final void Function(ZukkoChatException) _report;

  /// The last rejected subscription, while realtime waits for a slow retry.
  ZukkoChatException? _lastRejected;
  Timer? _retry;
  int _attempts = 0;
  ZukkoChatExceptionType? _reportedType;
  bool _disposed = false;

  /// The pubsub token was refused: read it again. A new token reconnects; the
  /// same one (or an exhausted refresh budget) leaves the socket closed, reports
  /// the failure once and schedules a retry. Never throws.
  Future<void> onRejected(ZukkoChatException error) async {
    final session = _session;
    _lastRejected = error;
    var failure = error;
    try {
      if (session != null &&
          await session.refresh(SessionRefreshReason.socketRejected)) {
        // the reset already reconnects; this covers a reset without a change
        if (!_disposed && _socket.state == ZukkoChatConnectionState.closed) {
          _socket.connect();
        }
        return;
      }
    } catch (e) {
      failure = e is ZukkoChatException ? e : error;
    }
    if (_disposed) return;
    if (_reportedType != failure.type) {
      _reportedType = failure.type; // once per kind until subscribed
      _report(failure);
    }
    _scheduleRetry();
  }

  /// Subscribed again: forget everything about the rejection.
  void onSubscribed() {
    _lastRejected = null;
    _attempts = 0;
    _reportedType = null;
    _cancelRetry();
  }

  /// The app is in the foreground again. Returns true when a rejection was
  /// pending and recovery restarted (the caller then must not connect itself).
  bool resume() {
    _cancelRetry();
    final last = _lastRejected;
    if (last == null) return false;
    unawaited(onRejected(last));
    return true;
  }

  /// A rejection with an unchanged token retries after 60 s, 120 s ... up to
  /// 10 min. Stops on dispose and when the session failed closed.
  void _scheduleRetry() {
    if (_disposed || _session?.failure != null) return;
    final delay = exponentialBackoff(
      attempt: _attempts++,
      base: _retryBase,
      max: _retryMax,
    );
    _cancelRetry();
    _retry = Timer(delay, () {
      _retry = null;
      final last = _lastRejected;
      if (_disposed || last == null) return;
      if (_socket.state != ZukkoChatConnectionState.closed) return;
      unawaited(onRejected(last));
    });
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }

  void dispose() {
    _disposed = true;
    _cancelRetry();
  }
}
