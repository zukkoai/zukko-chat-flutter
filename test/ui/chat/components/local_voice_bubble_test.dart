import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

import '../styles/styles_harness.dart';

class _Engine implements AudioEngine {
  final log = <String>[];
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<void> get completedStream => const Stream.empty();
  @override
  Future<Duration?> setUrl(String url) async {
    log.add('url $url');
    return const Duration(seconds: 3);
  }

  @override
  Future<Duration?> setFilePath(String path) async {
    log.add('file $path');
    return const Duration(seconds: 3);
  }

  @override
  Future<void> play() async => log.add('play');
  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> seek(Duration p) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory dir;
  late String file;
  late _Engine engine;
  late AudioPlaybackController playback;
  var rootTaps = 0;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('zukko_voice');
    file = '${dir.path}/note.m4a';
    File(file).writeAsBytesSync([0]);
    engine = _Engine();
    playback = AudioPlaybackController(engine: () => engine);
    rootTaps = 0;
  });
  tearDown(() {
    playback.dispose();
    dir.deleteSync(recursive: true);
  });

  for (final kind in ZukkoChatStyle.values) {
    Widget bubble(String source, MessageStatus status) {
      final style = kind.resolve(
        const ZukkoChatTheme(brightness: Brightness.light),
      );
      final env = ChatMessageEnv(
        l10n: const ZukkoChatL10n(),
        timeFormat: DateFormat('HH:mm'),
        userById: (id) => User(id: id),
        authorName: (id, me) => 'You',
        horizontalPadding: 16,
        audio: playback,
      );
      return MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => rootTaps++,
            child: messageOf(
              style.messageBuilders(env),
              AudioMessage(
                id: 'v',
                authorId: 'me',
                source: source,
                duration: const Duration(seconds: 3),
                createdAt: sampleTime,
                status: status,
              ),
              true,
            ),
          ),
        ),
      );
    }

    group(kind.name, () {
      testWidgets('a sending local voice note plays', (tester) async {
        await tester.pumpWidget(bubble(file, MessageStatus.sending));
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();
        expect(engine.log, ['file $file', 'play']);
      });

      testWidgets('play on a failed bubble does not hit the bubble tap', (
        tester,
      ) async {
        await tester.pumpWidget(bubble(file, MessageStatus.error));
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();
        expect(engine.log, contains('play'));
        expect(rootTaps, 0);
        await tester.tap(find.text('Not sent. Tap to retry'));
        expect(rootTaps, 1);
      });

      testWidgets('source swap stops the local note, no stuck state', (
        tester,
      ) async {
        await tester.pumpWidget(bubble(file, MessageStatus.sending));
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();
        await tester.pumpWidget(
          bubble('https://c.test/n.m4a', MessageStatus.sent),
        );
        expect(engine.log.last, 'pause');
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
