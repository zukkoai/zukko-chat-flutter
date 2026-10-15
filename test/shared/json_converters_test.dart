import 'package:zukko_chat_flutter/src/data/models/chatwoot_message.dart';
import 'package:zukko_chat_flutter/src/shared/json_converters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('intFromJson / idFromJson', () {
    test('accepts int, num and numeric strings', () {
      expect(intFromJson(5), 5);
      expect(intFromJson(5.9), 5);
      expect(intFromJson('12'), 12);
      expect(idFromJson(null), 0);
      expect(intFromJson('x'), isNull);
    });

    // SEC6: double.infinity.toInt() throws UnsupportedError
    test('non-finite and absurd numbers fall back instead of throwing', () {
      expect(intFromJson(double.infinity), isNull);
      expect(intFromJson(double.nan), isNull);
      expect(intFromJson(1e300), isNull);
      expect(idFromJson(1e300), 0);
    });
  });

  group('createdAtFromJson', () {
    test('unix seconds become ISO-8601 UTC', () {
      expect(createdAtFromJson(1626155918), '2021-07-13T05:58:38.000Z');
      expect(createdAtFromJson(1626155918.0), '2021-07-13T05:58:38.000Z');
      expect(createdAtFromJson('1626155918'), '2021-07-13T05:58:38.000Z');
    });

    test('strings are normalised to UTC', () {
      expect(
        createdAtFromJson('2021-07-13T08:38:38+02:00'),
        '2021-07-13T06:38:38.000Z',
      );
      expect(
        createdAtFromJson('2021-07-13T06:38:38Z'),
        '2021-07-13T06:38:38.000Z',
      );
    });

    test(
      'a string older SDK versions stored (local, no zone) still parses',
      () {
        final stored = DateTime(2021, 7, 13, 8, 38, 38).toString();

        expect(
          createdAtFromJson(stored),
          DateTime(2021, 7, 13, 8, 38, 38).toUtc().toIso8601String(),
        );
      },
    );

    // F11: an int and its ISO twin must be the same instant, same string
    test('numeric and ISO input of the same instant agree', () {
      expect(createdAtFromJson(100), createdAtFromJson('1970-01-01T00:01:40Z'));
    });

    // SEC6: 99999999999999999 -> RangeError, 1e999 -> UnsupportedError
    test('out of range, non-finite, negative and junk fall back to now', () {
      for (final bad in [
        99999999999999999,
        1e999,
        double.nan,
        -5,
        'garbage',
        null,
        <Object>[],
      ]) {
        final before = DateTime.now().toUtc().subtract(
          const Duration(seconds: 1),
        );
        final result = DateTime.parse(createdAtFromJson(bad));
        expect(result.isAfter(before), isTrue, reason: '$bad');
        expect(result.isUtc, isTrue);
      }
    });
  });

  group('parseList', () {
    test('skips items that fail to parse', () {
      final result = parseList([
        {'id': 1},
        'junk',
        {'id': 'boom'},
        {'id': 3},
      ], (m) => (m['id'] as int));

      expect(result, [1, 3]);
    });

    test('a non-list is a FormatException', () {
      expect(() => parseList({'a': 1}, (m) => m), throwsFormatException);
    });
  });

  test('parseMessages drops ids <= 0 and bad items', () {
    final result = parseMessages([
      {'id': 4, 'created_at': 1},
      {'id': 0},
      {'id': -1},
      {'content': 'no id at all'},
      {'id': 5, 'content': 5},
    ]);

    expect(result.map((m) => m.id), [4]);
  });

  test('ZukkoChatMessage.fromJson normalises created_at at parse time', () {
    final m = ZukkoChatMessage.fromJson({'id': 1, 'created_at': 1626155918});

    expect(m.createdAt, '2021-07-13T05:58:38.000Z');
  });
}
