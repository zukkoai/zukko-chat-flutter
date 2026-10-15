import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat_fakes.dart';

Map<String, dynamic> _img(String name) => {
  'file_type': 'image',
  'data_url': 'https://cdn.test/$name',
  'file_size': 2048,
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _hero(String tag) =>
    find.byWidgetPredicate((w) => w is Hero && w.tag == tag);

void main() {
  late FakeFactory factory;

  setUp(() => factory = FakeFactory());

  Future<void> open(
    WidgetTester tester,
    ZukkoChatStyle style,
    List<Map<String, dynamic>> files, {
    ZukkoChatInteractions interactions = const ZukkoChatInteractions(),
  }) async {
    factory.completer.complete(FakeClient());
    await tester.pumpWidget(
      MaterialApp(
        home: ZukkoChat(
          options: ZukkoChatOptions(
            baseUrl: 'https://x.test',
            websiteToken: 'in',
            style: style,
          ),
          clientFactory: factory.call,
          interactions: interactions,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    factory.callbacks!.onMessageReceived!(
      msg(1, content: null, attachments: files),
    );
    await _settle(tester);
  }

  for (final style in ZukkoChatStyle.values) {
    group(style.name, () {
      testWidgets(
        'tapping a single image opens the viewer with Hero on both sides',
        (tester) async {
          var messageTaps = 0;
          await open(
            tester,
            style,
            [_img('a.jpg')],
            interactions: ZukkoChatInteractions(
              onMessageTap: (_) => messageTaps++,
            ),
          );
          expect(_hero('zukko-image-1-0'), findsOneWidget);

          await tester.tap(_hero('zukko-image-1-0'));
          await _settle(tester);

          expect(find.byType(ImageViewer), findsOneWidget);
          expect(_hero('zukko-image-1-0'), findsNWidgets(2));
          expect(find.text('1 / 1'), findsNothing); // no counter for one image
          expect(messageTaps, 0);
        },
      );

      testWidgets(
        'gallery opens at the tapped index and swiping moves the counter',
        (tester) async {
          await open(tester, style, [
            _img('a.jpg'),
            _img('b.jpg'),
            _img('c.jpg'),
          ]);

          await tester.tap(_hero('zukko-image-1-1'));
          await _settle(tester);
          expect(find.text('2 / 3'), findsOneWidget);

          await tester.drag(find.byType(PageView), const Offset(-500, 0));
          await _settle(tester);
          expect(find.text('3 / 3'), findsOneWidget);
        },
      );
    });
  }

  group('viewer', () {
    Future<void> openGallery(WidgetTester tester) async {
      await open(tester, ZukkoChatStyle.values.first, [
        _img('a.jpg'),
        _img('b.jpg'),
        _img('c.jpg'),
      ]);
      await tester.tap(_hero('zukko-image-1-0'));
      await _settle(tester);
    }

    testWidgets('close button pops it', (tester) async {
      await openGallery(tester);
      await tester.tap(find.byIcon(Icons.close));
      await _settle(tester);
      expect(find.byType(ImageViewer), findsNothing);
    });

    testWidgets('system back pops it', (tester) async {
      await openGallery(tester);
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await _settle(tester);
      expect(find.byType(ImageViewer), findsNothing);
    });

    testWidgets('drag down past the threshold dismisses', (tester) async {
      await openGallery(tester);
      await tester.drag(find.byType(PageView), const Offset(0, 250));
      await _settle(tester);
      expect(find.byType(ImageViewer), findsNothing);
    });

    testWidgets('a small drag springs back', (tester) async {
      await openGallery(tester);
      await tester.drag(find.byType(PageView), const Offset(0, 40));
      await _settle(tester);
      expect(find.byType(ImageViewer), findsOneWidget);
      final y = tester.getTopLeft(find.byType(PageView)).dy;
      expect(y, 0);
    });

    testWidgets('double tap zooms in and blocks paging', (tester) async {
      await openGallery(tester);
      final page = find.byType(PageView);
      await tester.tap(page);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(page);
      await _settle(tester);

      await tester.drag(page, const Offset(-300, 0));
      await _settle(tester);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('close button has the l10n label', (tester) async {
      final semantics = tester.ensureSemantics();
      await openGallery(tester);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      expect(find.bySemanticsLabel('Image 1 / 3'), findsOneWidget);
      semantics.dispose();
    });
  });

  test('dismiss rule: distance or velocity', () {
    expect(shouldDismissImageViewer(40, 0), isFalse);
    expect(shouldDismissImageViewer(150, 0), isTrue);
    expect(shouldDismissImageViewer(-20, -900), isTrue);
  });
}
