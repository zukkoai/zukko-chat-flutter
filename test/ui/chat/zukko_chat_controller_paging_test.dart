import 'dart:async';

import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fakes.dart';

const _options = ZukkoChatOptions(
  baseUrl: 'https://x.test',
  websiteToken: 'in',
);

/// Messages [from]..[to] inclusive, oldest first.
List<ZukkoChatMessage> _range(int from, int to) => [
  for (var i = from; i <= to; i++) msg(i),
];

void main() {
  late FakeFactory factory;
  late FakeClient client;
  late SpyChat chat;
  late ZukkoChatController controller;
  late List<ZukkoChatException> errors;

  setUp(() {
    factory = FakeFactory();
    client = FakeClient();
    errors = [];
    chat = SpyChat();
    controller = ZukkoChatController(
      _options,
      callbacks: ZukkoChatCallbacks(onError: errors.add),
      clientFactory: factory.call,
      chat: chat,
    );
  });

  tearDown(() => controller.dispose());

  Future<void> open(List<ZukkoChatMessage> latest) async {
    client.loadGate = Completer<void>();
    factory.completer.complete(client);
    await pumpEventQueue();
    factory.callbacks!.onMessagesRetrieved!(latest);
    client.loadGate!.complete();
    await pumpEventQueue();
  }

  test('open shows the latest page; scrolling to the top adds the 20 older '
      'ones, in order, no duplicates', () async {
    client.older = (before) async => _range(before - 20, before - 1);
    await open(_range(81, 100));
    expect(chat.messages.length, 20);

    await controller.loadOlder();
    await pumpEventQueue();

    expect(client.olderRequests, [81]);
    expect(chat.messages.length, 40);
    expect(chat.messages.first.id, '61');
    expect(chat.messages.last.id, '100');
    // the cursor moved: the next page is asked before 61
    await controller.loadOlder();
    expect(client.olderRequests, [81, 61]);
    expect(chat.messages.length, 60);
  });

  test('a short page ends paging: no further request', () async {
    client.older = (before) async => _range(1, 5);
    await open(_range(26, 45));

    await controller.loadOlder();
    await controller.loadOlder();
    await controller.loadOlder();

    expect(client.olderRequests, [26]);
    expect(chat.messages.length, 25);
  });

  test('a short latest page means nothing older: no request at all', () async {
    await open(_range(1, 7));

    await controller.loadOlder();

    expect(client.olderRequests, isEmpty);
  });

  test('concurrent calls make one request', () async {
    final gate = Completer<List<ZukkoChatMessage>?>();
    client.older = (_) => gate.future;
    await open(_range(81, 100));

    final a = controller.loadOlder();
    final b = controller.loadOlder();
    final c = controller.loadOlder();
    gate.complete(_range(61, 80));
    await Future.wait([a, b, c]);

    expect(client.olderRequests, [81]);
    expect(chat.messages.length, 40);
  });

  test('a failed load keeps the list; the next call retries', () async {
    client.older = (_) async => null;
    await open(_range(81, 100));

    await controller.loadOlder();
    expect(chat.messages.length, 20);

    client.older = (before) async => _range(61, 80);
    await controller.loadOlder();

    expect(client.olderRequests, [81, 81]);
    expect(chat.messages.length, 40);
  });

  test('a throwing client does not break the chat', () async {
    client.older = (_) async => throw StateError('boom');
    await open(_range(81, 100));

    await controller.loadOlder();
    await controller.loadOlder();

    expect(chat.messages.length, 20);
    expect(client.olderRequests.length, 2); // retried, once per call
  });

  test('a reconnect catch-up does not move the paging cursor', () async {
    client.older = (before) async => _range(before - 20, before - 1);
    await open(_range(81, 100));

    factory.callbacks!.onMessagesRetrieved!(_range(101, 103));
    await pumpEventQueue();
    await controller.loadOlder();

    expect(client.olderRequests, [81]);
  });

  test('a page overlapping known messages adds no duplicates', () async {
    client.older = (_) async => _range(70, 89); // overlaps 81..89
    await open(_range(81, 100));

    await controller.loadOlder();

    expect(chat.messages.length, 31);
    expect({for (final m in chat.messages) m.id}.length, 31);
  });

  test('nothing is requested before the first server page arrives', () async {
    factory.completer.complete(client);
    await pumpEventQueue();

    await controller.loadOlder();

    expect(client.olderRequests, isEmpty);
  });

  test('a replaced client finishing its load late does not clear the new '
      "client's first-page flag", () async {
    client.loadGate = Completer<void>();
    factory.completer.complete(client);
    await pumpEventQueue();
    factory.callbacks!.onError!(
      ZukkoChatException('x', ZukkoChatExceptionType.sessionExpired),
    );
    factory.completer = Completer<ZukkoChatClient>();
    controller.retry();
    final fresh = FakeClient()..loadGate = Completer<void>();
    factory.completer.complete(fresh);
    await pumpEventQueue();

    client.loadGate!.complete(); // the old _start wakes up late
    await pumpEventQueue();
    factory.callbacks!.onMessagesRetrieved!(_range(1, 5)); // short: all there
    fresh.loadGate!.complete();
    await pumpEventQueue();

    await controller.loadOlder();
    expect(fresh.olderRequests, isEmpty);
  });
}
