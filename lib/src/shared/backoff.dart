import 'dart:math';

final _random = Random();

/// `base * 2^attempt`, plus up to [jitter] (a fraction, 0.25 = 25 %) of that
/// as random extra, never more than [max].
Duration exponentialBackoff({
  required int attempt,
  required Duration base,
  required Duration max,
  double jitter = 0,
  Random? random,
}) {
  final raw = base.inMilliseconds * (1 << attempt.clamp(0, 20));
  final extra = jitter > 0
      ? (random ?? _random).nextInt((raw * jitter).toInt() + 1)
      : 0;
  return Duration(milliseconds: min(max.inMilliseconds, raw + extra));
}

/// Realtime reconnect delay: `1 s * 2^attempt` plus up to 25 % jitter, at most
/// 30 s.
Duration defaultSocketBackoff(int attempt, [Random? random]) =>
    exponentialBackoff(
      attempt: attempt,
      base: const Duration(seconds: 1),
      max: const Duration(seconds: 30),
      jitter: 0.25,
      random: random,
    );
