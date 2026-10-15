import 'package:zukko_chat_flutter/src/data/models/message_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fixtures.dart';

void main() {
  List<int> order(List<(int, String)> input) => sortMessagesOldestFirst([
    for (final (id, at) in input) message(id, createdAt: at),
  ]).map((m) => m.id).toList();

  test('sorts by the instant, whatever the string format', () {
    expect(
      order([
        (1, '2024-01-01T09:00:00Z'),
        (2, '2024-01-01T10:00:00+02:00'), // 08:00 UTC
        (3, '2024-01-01 07:00:00Z'),
      ]),
      [3, 2, 1],
    );
  });

  // F11: controller tie-break was lexicographic ("10" < "9")
  test('same instant: ids compare as numbers', () {
    expect(order([(10, '2024-01-01T00:00:00Z'), (9, '2024-01-01T00:00:00Z')]), [
      9,
      10,
    ]);
  });

  // F11: int created_at 100 vs "1970-01-01T00:01:41Z" (101 s)
  test('a numeric created_at and an ISO one interleave correctly', () {
    expect(
      order([(2, '1970-01-01T00:01:41.000Z'), (1, '1970-01-01T00:01:40.000Z')]),
      [1, 2],
    );
  });

  test('unparseable timestamps sort first instead of throwing', () {
    expect(order([(1, '2024-01-01T00:00:00Z'), (2, 'garbage')]), [2, 1]);
  });

  test('does not modify its input and accepts any iterable', () {
    final input = [
      message(2, createdAt: '2024-01-02'),
      message(1, createdAt: '2024-01-01'),
    ];

    final sorted = sortMessagesOldestFirst(input.reversed);

    expect(input.first.id, 2);
    expect(sorted.map((m) => m.id), [1, 2]);
  });

  test('compareByTimeThenId is the order sortMessagesOldestFirst uses', () {
    final a = message(2, createdAt: '2024-01-01T00:00:00Z');
    final b = message(1, createdAt: '2024-01-01T00:00:00Z');
    final c = message(3, createdAt: '2023-12-31T00:00:00Z');

    expect(compareByTimeThenId(a, b), greaterThan(0)); // same instant: by id
    expect(compareByTimeThenId(c, b), lessThan(0)); // earlier first
    expect([a, b, c]..sort(compareByTimeThenId), [c, b, a]);
  });
}
