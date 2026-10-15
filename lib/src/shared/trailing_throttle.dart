import 'dart:async';

/// Runs [_action] at most once per [every]; calls inside the window collapse
/// into one trailing run when the window ends.
class TrailingThrottle {
  TrailingThrottle(this.every, this._action);

  final Duration every;
  final Future<void> Function() _action;
  Timer? _cooldown;
  bool _pending = false;
  bool _disposed = false;

  /// Runs the action now (returning its future) or, inside the window, marks
  /// a trailing run and completes at once.
  Future<void> call() {
    if (_disposed) return Future.value();
    if (_cooldown != null) {
      _pending = true;
      return Future.value();
    }
    _cooldown = Timer(every, () {
      _cooldown = null;
      if (_pending && !_disposed) {
        _pending = false;
        unawaited(call());
      }
    });
    return _action();
  }

  void dispose() {
    _disposed = true;
    _cooldown?.cancel();
    _cooldown = null;
  }
}
