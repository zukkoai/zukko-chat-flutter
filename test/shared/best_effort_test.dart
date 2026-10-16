import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/best_effort.dart';

void main() {
  test('runs the action and never throws', () async {
    var ran = false;
    await bestEffort(() async => ran = true, 'x');
    expect(ran, isTrue);

    await bestEffort(() async => throw StateError('boom'), 'x');
    await bestEffort(() => throw StateError('sync boom'), 'x');
  });
}
