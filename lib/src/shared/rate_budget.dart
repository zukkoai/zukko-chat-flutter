/// At most [max] spends per sliding [window]; used to keep a broken server
/// from causing a rebuild loop.
class RateBudget {
  RateBudget({
    required this.max,
    required this.window,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int max;
  final Duration window;
  final DateTime Function() _now;
  final _spent = <DateTime>[];

  /// True while another [spend] is allowed.
  bool get hasRoom {
    final now = _now();
    _spent.removeWhere((t) => now.difference(t) >= window);
    return _spent.length < max;
  }

  void spend() => _spent.add(_now());
}
