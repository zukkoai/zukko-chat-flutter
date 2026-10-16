import 'dart:async';

/// The "user is typing" signal sent to the agents: on at the first
/// [ping], off after [idle] without one (or at [stop]).
class OutgoingTyping {
  /// Without input for this long the user counts as not typing any more.
  static const defaultIdle = Duration(seconds: 3);

  OutgoingTyping(this._emit, {this.idle = defaultIdle});

  final void Function(bool typing) _emit;
  final Duration idle;
  bool _on = false;
  Timer? _timer;

  /// The user did something that counts as typing.
  void ping() {
    if (!_on) {
      _on = true;
      _emit(true);
    }
    _timer?.cancel();
    _timer = Timer(idle, stop);
  }

  /// Typing ended (idle, or a message was sent).
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (!_on) return;
    _on = false;
    _emit(false);
  }

  bool get isOn => _on;

  /// Cancels the timer without sending "off" (the owner does that itself).
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
