import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'chat_fakes.dart';

const _o = ZukkoChatOptions(baseUrl: 'https://x.test', websiteToken: 'in');

void main() {
  late FakeFactory factory;
  late FakeClient client;

  setUp(() {
    factory = FakeFactory();
    client = FakeClient();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  double fromBottom(WidgetTester tester) {
    final p = position(tester);
    return p.maxScrollExtent - p.pixels;
  }

  /// A chat opened with 20 tall messages (the list scrolls), at the bottom.
  Future<void> openChat(WidgetTester tester) async {
    client.loadGate = Completer<void>();
    client.older = (before) async => [
      for (var i = before - 20; i < before; i++) msg(i, content: 'old$i\n\nx'),
    ];
    factory.completer.complete(client);
    await tester.pumpWidget(MaterialApp(home: ZukkoChat(options: _o)));
    await tester.pump();
    factory.callbacks!.onMessagesRetrieved!([
      for (var i = 101; i <= 120; i++) msg(i, content: 'm$i\n\n\nx'),
    ]);
    client.loadGate!.complete();
    await settle(tester);
    // The list is lazy: jump until the estimated extent is exact.
    for (var i = 0; i < 5; i++) {
      position(tester).jumpTo(position(tester).maxScrollExtent);
      await tester.pump();
    }
    await settle(tester);
    expect(fromBottom(tester), 0);
  }

  Future<void> scrollUp(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
    await settle(tester);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await settle(tester);
  }

  testWidgets('scrolled up a bit, the user sends: the list goes to the '
      'bottom', (tester) async {
    await openChat(tester);
    await scrollUp(tester, 150);
    expect(fromBottom(tester), greaterThan(100));

    await send(tester, 'mine');

    expect(client.sent.single.content, 'mine');
    expect(fromBottom(tester), 0);
  });

  testWidgets('the user sends, then the reply arrives: it is scrolled into '
      'view', (tester) async {
    await openChat(tester);
    await scrollUp(tester, 150);
    await send(tester, 'mine');

    factory.callbacks!.onMessageReceived!(
      msg(200, content: 'reply\n\n\n\n\nend', createdAt: '2024-01-01 11:00:00'),
    );
    await settle(tester);

    expect(fromBottom(tester), 0);
  });

  testWidgets('near the bottom, an incoming message is scrolled into view', (
    tester,
  ) async {
    await openChat(tester);
    await scrollUp(tester, 150);

    factory.callbacks!.onMessageReceived!(
      msg(200, content: 'hi\n\n\n\n\nend', createdAt: '2024-01-01 11:00:00'),
    );
    await settle(tester);

    expect(fromBottom(tester), 0);
  });

  testWidgets('far up in the history, an incoming message keeps the '
      'position', (tester) async {
    await openChat(tester);
    for (var i = 0; i < 4; i++) {
      await scrollUp(tester, 400);
    }
    final before = position(tester).pixels;
    expect(fromBottom(tester), greaterThan(1500));

    factory.callbacks!.onMessageReceived!(
      msg(200, content: 'hi', createdAt: '2024-01-01 11:00:00'),
    );
    await settle(tester);

    expect(position(tester).pixels, before);
    expect(fromBottom(tester), greaterThan(1500));
  });

  testWidgets('loading an older page does not jump to the bottom', (
    tester,
  ) async {
    await openChat(tester);
    for (var i = 0; i < 12; i++) {
      await scrollUp(tester, 500);
    }
    tester.view.physicalSize = const Size(2400, 2100);
    addTearDown(tester.view.resetPhysicalSize);
    await settle(tester);

    expect(client.olderRequests.first, 101, reason: 'older page was loaded');
    expect(fromBottom(tester), greaterThan(1500));
  });

  testWidgets('after the controller is replaced (new options) an incoming '
      'message near the bottom still scrolls into view', (tester) async {
    await openChat(tester);
    await scrollUp(tester, 150);

    // Different connection: the view disposes and recreates its controller.
    client = FakeClient()..loadGate = Completer<void>();
    factory.completer = Completer<ZukkoChatClient>()..complete(client);
    await tester.pumpWidget(
      MaterialApp(
        home: ZukkoChat(
          options: const ZukkoChatOptions(
            baseUrl: 'https://y.test',
            websiteToken: 'other',
          ),
        ),
      ),
    );
    await tester.pump();
    factory.callbacks!.onMessagesRetrieved!([
      for (var i = 101; i <= 120; i++) msg(i, content: 'n$i\n\n\nx'),
    ]);
    client.loadGate!.complete();
    await settle(tester);
    for (var i = 0; i < 5; i++) {
      position(tester).jumpTo(position(tester).maxScrollExtent);
      await tester.pump();
    }
    await scrollUp(tester, 150);
    expect(fromBottom(tester), greaterThan(100));

    factory.callbacks!.onMessageReceived!(
      msg(200, content: 'hi\n\n\n\n\nend', createdAt: '2024-01-01 11:00:00'),
    );
    await settle(tester);

    expect(fromBottom(tester), 0);
  });
}
