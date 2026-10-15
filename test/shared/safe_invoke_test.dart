import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/safe_invoke.dart';

void main() {
  test('runs the callback', () {
    var n = 0;
    safeInvoke(() => n++, 'x');
    expect(n, 1);
  });

  test('swallows a throwing callback', () {
    expect(
      () => safeInvoke(() => throw StateError('boom'), 'x'),
      returnsNormally,
    );
  });
}
