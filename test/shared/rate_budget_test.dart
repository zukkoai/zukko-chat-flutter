import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/rate_budget.dart';

void main() {
  test('allows max spends per window, then frees up', () {
    var now = DateTime(2026);
    final budget = RateBudget(
      max: 2,
      window: const Duration(seconds: 60),
      now: () => now,
    );

    expect(budget.hasRoom, isTrue);
    budget.spend();
    budget.spend();
    expect(budget.hasRoom, isFalse);

    now = now.add(const Duration(seconds: 59));
    expect(budget.hasRoom, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(budget.hasRoom, isTrue);
  });
}
