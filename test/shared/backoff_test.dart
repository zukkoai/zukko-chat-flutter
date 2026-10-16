import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/backoff.dart';

void main() {
  Duration b(int attempt, {double jitter = 0, Random? random}) =>
      exponentialBackoff(
        attempt: attempt,
        base: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
        jitter: jitter,
        random: random,
      );

  test('doubles per attempt and caps at max', () {
    expect(b(0), const Duration(seconds: 1));
    expect(b(3), const Duration(seconds: 8));
    expect(b(5), const Duration(seconds: 30));
    expect(b(500), const Duration(seconds: 30));
  });

  test('jitter adds up to the fraction, still capped', () {
    for (var i = 0; i < 50; i++) {
      final ms = b(2, jitter: 0.25, random: Random(i)).inMilliseconds;
      expect(ms, inInclusiveRange(4000, 5000));
    }
    expect(b(10, jitter: 0.25).inSeconds, 30);
  });
}
