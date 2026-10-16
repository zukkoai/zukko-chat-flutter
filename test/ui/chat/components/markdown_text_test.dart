import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/smooth_silk/smooth_silk_message_spec.dart';
import 'package:zukko_chat_flutter/src/ui/chat/styles/smooth_silk/smooth_silk_tokens.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

const _body = TextStyle(fontSize: 15, color: Color(0xFF102030));
const _link = TextStyle(
  fontSize: 15,
  color: Color(0xFF102030),
  decoration: TextDecoration.underline,
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pump(WidgetTester t, String text, {void Function(Uri)? onOpen}) =>
    t.pumpWidget(
      _host(
        MarkdownText(
          text: text,
          style: _body,
          linkStyle: _link,
          onOpen: onOpen,
        ),
      ),
    );

/// One leaf of rendered text with the style and recognizer inherited from
/// its ancestor spans.
class _Leaf {
  final String text;
  final TextStyle style;
  final GestureRecognizer? recognizer;
  _Leaf(this.text, this.style, this.recognizer);
}

List<_Leaf> _leaves(WidgetTester t) {
  final out = <_Leaf>[];
  void walk(InlineSpan s, TextStyle style, GestureRecognizer? rec) {
    if (s is! TextSpan) return;
    final st = s.style == null ? style : style.merge(s.style);
    final r = s.recognizer ?? rec;
    if (s.text != null) out.add(_Leaf(s.text!, st, r));
    for (final c in s.children ?? const <InlineSpan>[]) {
      walk(c, st, r);
    }
  }

  for (final w in t.widgetList<RichText>(find.byType(RichText))) {
    walk(w.text, const TextStyle(), null);
  }
  return out;
}

_Leaf _find(WidgetTester t, String text) =>
    _leaves(t).firstWhere((s) => s.text == text);

void main() {
  testWidgets('bold, italic, strike and code get their styles', (t) async {
    await _pump(t, '**bold** *it* ~~gone~~ `code`');
    expect(_find(t, 'bold').style.fontWeight, FontWeight.w600);
    expect(_find(t, 'it').style.fontStyle, FontStyle.italic);
    expect(_find(t, 'gone').style.decoration, TextDecoration.lineThrough);
    expect(_find(t, 'code').style.fontFamily, 'monospace');
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });

  testWidgets('headings are bold and scaled, lists get bullets and numbers', (
    t,
  ) async {
    await _pump(t, '# Title\n\n- one\n- two\n\n1. first\n2. second');
    final h = t.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'Title',
      ),
    );
    expect((h.text as TextSpan).style?.fontSize, greaterThan(15));
    expect((h.text as TextSpan).style?.fontWeight, FontWeight.w600);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });

  testWidgets('a Markdown link opens through the link handler', (t) async {
    final opened = <Uri>[];
    await _pump(
      t,
      'Read [the docs](https://zukko.ai/docs) now',
      onOpen: opened.add,
    );
    final link = _find(t, 'the docs');
    expect(link.style.decoration, TextDecoration.underline);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    expect(opened, [Uri.parse('https://zukko.ai/docs')]);
  });

  testWidgets('unsafe link schemes are not tappable', (t) async {
    await _pump(t, '[x](javascript:alert(1))');
    final tappable = _find(t, 'x').recognizer != null;
    expect(tappable, isFalse);
  });

  testWidgets('raw HTML stays literal text', (t) async {
    await _pump(t, '<script>alert(1)</script> and <b>x</b>');
    final all = t
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .join();
    expect(all, contains('<script>alert(1)</script>'));
    expect(all, contains('<b>x</b>'));
  });

  testWidgets('images are shown as a link, not loaded', (t) async {
    await _pump(t, '![logo](https://zukko.ai/a.png)');
    expect(find.byType(Image), findsNothing);
    expect(_find(t, 'logo'), isNotNull);
  });

  testWidgets('tables render as a grid, code blocks as monospace', (t) async {
    await _pump(t, '| a | b |\n|---|---|\n| 1 | 2 |\n\n```\nx = 1\n```');
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(_find(t, 'x = 1').style.fontFamily, 'monospace');
  });

  testWidgets('plain text with a link renders as before (LinkifiedText)', (
    t,
  ) async {
    await _pump(t, 'Hello! See https://zukko.ai/docs for the details.');
    expect(find.byType(LinkifiedText), findsOneWidget);
  });

  group('ChatText', () {
    final spec = smoothSilkMessageSpec(
      SmoothSilkTokens.from(const ZukkoChatTheme(brightness: Brightness.light)),
    );
    TextMessage msg() => TextMessage(
      id: 'm',
      authorId: 'a',
      text: '**x** here',
      createdAt: DateTime.utc(2026),
    );

    testWidgets('incoming message renders Markdown', (t) async {
      await t.pumpWidget(
        _host(ChatTextMessage(message: msg(), isSentByMe: false, spec: spec)),
      );
      expect(_find(t, 'x').style.fontWeight, FontWeight.w600);
    });

    testWidgets('visitor message stays plain', (t) async {
      await t.pumpWidget(
        _host(ChatTextMessage(message: msg(), isSentByMe: true, spec: spec)),
      );
      expect(find.byType(MarkdownText), findsNothing);
      expect(
        t.widgetList<RichText>(find.byType(RichText)).first.text.toPlainText(),
        '**x** here',
      );
    });
  });
}
