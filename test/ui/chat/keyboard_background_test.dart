import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'chat_fakes.dart';

void main() {
  late FakeFactory factory;

  setUp(() {
    factory = FakeFactory();
  });

  for (final style in ZukkoChatStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'scaffold behind keyboard matches ${style.name} $brightness',
        (tester) async {
          factory.completer.complete(FakeClient());
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                scaffoldBackgroundColor: Colors.red,
              ),
              home: ZukkoChat(
                options: ZukkoChatOptions(
                  baseUrl: 'https://x.test',
                  websiteToken: 'in',
                  style: style,
                ),
              ),
            ),
          );
          await tester.pump();

          final expected = style
              .resolve(
                ZukkoChatTheme.fromThemeData(ThemeData(brightness: brightness)),
              )
              .backgroundColor;
          expect(expected, isNot(Colors.red));
          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            expected,
          );
        },
      );
    }
  }
}
