import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/sdk_log.dart';

void main() {
  test('level prefixes', () {
    final logs = <String>[];
    final saved = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
    addTearDown(() => debugPrint = saved);

    sdkLog('a', level: SdkLogLevel.error);
    sdkLog('b', level: SdkLogLevel.warning);
    sdkLog('c');

    expect(logs, [
      '[zukko_chat] ERROR: a',
      '[zukko_chat] WARNING: b',
      '[zukko_chat] c',
    ]);
  });
}
