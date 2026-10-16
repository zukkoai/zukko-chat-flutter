import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_connection_state.dart';
import 'package:zukko_chat_flutter/src/ui/chat/chat_connection_banner.dart';
import 'package:zukko_chat_flutter/src/ui/chat/chat_connection_monitor.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';

const _s = Duration(seconds: 1);

void _run(
  void Function(FakeAsync async, ChatConnectionMonitor m, List<String> log)
  body, {
  required bool Function() online,
}) => fakeAsync((async) {
  final log = <String>[];
  final m = ChatConnectionMonitor(
    host: 'chat.example',
    onBackOnline: () => log.add('online'),
    probe: (_) async => online(),
  );
  body(async, m, log);
  m.dispose();
});

void main() {
  test('hidden while connected and during a normal first connect', () {
    _run((async, m, _) {
      m.onState(ZukkoChatConnectionState.connecting);
      async.elapse(_s);
      m.onState(ZukkoChatConnectionState.subscribed);
      async.elapse(_s * 10);
      expect(m.notice, ChatConnectionNotice.none);
    }, online: () => true);
  });

  test('no flash for a 1 s blip', () {
    _run((async, m, _) {
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(_s);
      m.onState(ZukkoChatConnectionState.subscribed);
      async.elapse(_s * 10);
      expect(m.notice, ChatConnectionNotice.none);
    }, online: () => false);
  });

  test('offline after the delay, hides on reconnect', () {
    _run((async, m, _) {
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(const Duration(milliseconds: 1900));
      expect(m.notice, ChatConnectionNotice.none);
      async.elapse(const Duration(milliseconds: 200));
      expect(m.notice, ChatConnectionNotice.offline);
      m.onState(ZukkoChatConnectionState.subscribed);
      expect(m.notice, ChatConnectionNotice.none);
    }, online: () => false);
  });

  test('connecting when the host resolves but the socket is down', () {
    _run((async, m, log) {
      m.onState(ZukkoChatConnectionState.connecting);
      async.elapse(_s * 3);
      expect(m.notice, ChatConnectionNotice.connecting);
      expect(log, isEmpty); // never offline: nothing to kick
    }, online: () => true);
  });

  test('triggers a reconnect when connectivity returns', () {
    var online = false;
    _run((async, m, log) {
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(_s * 3);
      expect(m.notice, ChatConnectionNotice.offline);
      online = true;
      async.elapse(_s * 3);
      expect(log, ['online']);
      expect(m.notice, ChatConnectionNotice.connecting);
      async.elapse(_s * 9);
      expect(log, ['online']); // once, not on every recheck
    }, online: () => online);
  });

  test('a probe still running when the socket recovers and drops again '
      'does not start a second recheck loop', () {
    fakeAsync((async) {
      var probes = 0;
      final m = ChatConnectionMonitor(
        host: 'h',
        onBackOnline: () {},
        // the first answer is slow, the others immediate
        probe: (_) => probes++ == 0
            ? Future.delayed(_s * 2, () => false)
            : Future.value(false),
      );
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(const Duration(milliseconds: 2500)); // probe #1 running
      m.onState(ZukkoChatConnectionState.subscribed);
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(_s * 2); // t=4.5: stale answer came at t=4, new loop probes
      probes = 0;
      async.elapse(_s * 12);
      expect(probes, lessThanOrEqualTo(4)); // one loop: every 3 s
      m.dispose();
    });
  });

  test('a throwing onBackOnline does not stop the rechecks', () {
    var online = false;
    var probes = 0;
    fakeAsync((async) {
      final m = ChatConnectionMonitor(
        host: 'h',
        onBackOnline: () => throw StateError('resume failed'),
        probe: (_) async {
          probes++;
          return online;
        },
      );
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(_s * 3);
      expect(m.notice, ChatConnectionNotice.offline);
      online = true;
      async.elapse(_s * 3);
      final after = probes;
      async.elapse(_s * 6);
      expect(probes, greaterThan(after));
      m.dispose();
    });
  });

  test('no probe loop after dispose', () {
    var probes = 0;
    fakeAsync((async) {
      final m = ChatConnectionMonitor(
        host: 'h',
        onBackOnline: () {},
        probe: (_) async {
          probes++;
          return false;
        },
      );
      m.onState(ZukkoChatConnectionState.backoff);
      async.elapse(_s * 3);
      m.dispose();
      final at = probes;
      async.elapse(_s * 30);
      expect(probes, at);
    });
  });

  test('an empty host is never reported offline', () async {
    expect(await resolvesHost(''), isTrue);
  });

  testWidgets('banner shows the localized text and nothing when connected', (
    tester,
  ) async {
    final m = ChatConnectionMonitor(
      host: 'h',
      onBackOnline: () {},
      probe: (_) async => false,
    );
    addTearDown(m.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChatConnectionBanner(
          monitor: m,
          l10n: const ZukkoChatL10n(),
          color: Colors.black,
          horizontalPadding: 8,
        ),
      ),
    );
    expect(find.text('No internet connection'), findsNothing);
    m.onState(ZukkoChatConnectionState.backoff);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No internet connection'), findsOneWidget);
    m.onState(ZukkoChatConnectionState.subscribed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No internet connection'), findsNothing);
  });
}
