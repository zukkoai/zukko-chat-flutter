import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/chat_attachment_flow.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';

import 'chat_fakes.dart';

const _o = ZukkoChatOptions(baseUrl: 'https://x.test', websiteToken: 'in');
const _max = ZukkoChatUpload.maxMessageLength;
final _l10n = const ZukkoChatL10n();

class _ConfigClient extends FakeClient {
  final ZukkoChatConfig? _config;
  _ConfigClient(this._config);

  @override
  ZukkoChatConfig? get config => _config;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _openChat(
  WidgetTester tester, {
  required ZukkoChatClient client,
  ZukkoChatStyle style = ZukkoChatStyle.smoothSilk,
}) async {
  final factory = FakeFactory();
  await tester.pumpWidget(
    MaterialApp(
      home: ZukkoChat(
        options: ZukkoChatOptions(
          baseUrl: _o.baseUrl,
          websiteToken: _o.websiteToken,
          style: style,
        ),
        clientFactory: factory.call,
      ),
    ),
  );
  factory.completer.complete(client);
  await _settle(tester);
}

VoidCallback? _sendHandler(WidgetTester tester) => tester
    .widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward_rounded),
        matching: find.byType(IconButton),
      ),
    )
    .onPressed;

ZukkoChatUpload _file(String name, {int size = 10}) =>
    ZukkoChatUpload.file(name: name, path: '/x/$name', size: size);

void main() {
  group('microphone follows the inbox setting', () {
    for (final style in ZukkoChatStyle.values) {
      testWidgets('${style.name}: hidden only when audio is explicitly off', (
        tester,
      ) async {
        await _openChat(
          tester,
          style: style,
          client: _ConfigClient(
            ZukkoChatConfig.fromJson({'audio_messaging_enabled': false}),
          ),
        );
        expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
      });

      testWidgets('${style.name}: shown when audio is on', (tester) async {
        await _openChat(
          tester,
          style: style,
          client: _ConfigClient(
            ZukkoChatConfig.fromJson({'audio_messaging_enabled': true}),
          ),
        );
        expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      });
    }

    testWidgets('shown while the config is unknown', (tester) async {
      await _openChat(tester, client: _ConfigClient(null));
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });
  });

  group('message text limit', () {
    for (final style in ZukkoChatStyle.values) {
      testWidgets('${style.name}: over the limit disables send and warns', (
        tester,
      ) async {
        final client = _ConfigClient(null);
        await _openChat(tester, style: style, client: client);

        await tester.enterText(find.byType(TextField), 'a' * (_max + 1));
        await tester.pump();
        expect(_sendHandler(tester), isNull);
        expect(find.text(_l10n.messageTooLong(_max)), findsOneWidget);

        // the warning goes away by itself
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text(_l10n.messageTooLong(_max)), findsNothing);
        expect(_sendHandler(tester), isNull);

        // shortening re-enables send, and it sends
        await tester.enterText(find.byType(TextField), 'a' * _max);
        await tester.pump();
        expect(_sendHandler(tester), isNotNull);
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await _settle(tester);
        expect(client.sent.single.content.length, _max);
      });
    }
  });

  group('message length counts code points', () {
    for (final n in [_max, _max + 1]) {
      testWidgets('$n emoji ${n > _max ? 'blocked' : 'allowed'}', (
        tester,
      ) async {
        await _openChat(tester, client: _ConfigClient(null));
        await tester.enterText(find.byType(TextField), '😀' * n);
        await tester.pump();
        expect(_sendHandler(tester), n > _max ? isNull : isNotNull);
      });
    }
  });

  group('attachment limits', () {
    test('a file over the size limit is left out', () {
      final pick = screenAttachments([
        _file('a.png'),
        _file('big.png', size: ZukkoChatUpload.maxSize + 1),
      ]);
      expect(pick.fitting.map((f) => f.name), ['a.png']);
      expect(pick.tooLarge, 1);
      expect(attachmentWarning(_l10n, pick), _l10n.fileTooLarge(40));
    });

    test('the 16th file is left out, the first 15 stay', () {
      final pick = screenAttachments([
        for (var i = 0; i < 16; i++) _file('f$i.png'),
      ]);
      expect(pick.fitting, hasLength(ZukkoChatUpload.maxAttachments));
      expect(pick.overCount, 1);
      expect(attachmentWarning(_l10n, pick), _l10n.tooManyFiles(15));
    });

    test('a type the server rejects is left out', () {
      final pick = screenAttachments([
        _file('a.pdf'),
        _file('a.docx'),
        _file('movie.mp4'),
        _file('tool.exe'),
        _file('noextension'),
      ]);
      expect(pick.fitting.map((f) => f.name), ['a.pdf', 'a.docx', 'movie.mp4']);
      expect(pick.badType, 2);
      expect(attachmentWarning(_l10n, pick), _l10n.fileTypeNotSupportedText);
    });

    test('nothing to warn about when everything fits', () {
      final pick = screenAttachments([_file('a.png'), _file('b.txt')]);
      expect(pick.fitting, hasLength(2));
      expect(attachmentWarning(_l10n, pick), isNull);
    });
  });
}
