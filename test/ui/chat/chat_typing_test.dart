import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/chat_typing.dart';

void main() {
  test('on at the first ping, off after the idle time, pings extend it', () {
    fakeAsync((async) {
      final log = <bool>[];
      final typing = OutgoingTyping(log.add);
      typing.ping();
      typing.ping();
      expect(log, [true]);
      async.elapse(OutgoingTyping.defaultIdle - const Duration(seconds: 1));
      typing.ping();
      async.elapse(OutgoingTyping.defaultIdle - const Duration(seconds: 1));
      expect(log, [true]);
      async.elapse(const Duration(seconds: 1));
      expect(log, [true, false]);
      expect(typing.isOn, isFalse);
    });
  });

  test('stop sends off once; dispose is silent', () {
    fakeAsync((async) {
      final log = <bool>[];
      final typing = OutgoingTyping(log.add);
      typing.stop();
      expect(log, isEmpty);
      typing.ping();
      typing.stop();
      typing.stop();
      expect(log, [true, false]);
      typing.ping();
      typing.dispose();
      async.elapse(const Duration(minutes: 1));
      expect(log, [true, false, true]);
    });
  });
}
