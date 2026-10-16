import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';
import 'package:zukko_chat_flutter/src/ui/l10n/zukko_chat_l10n.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

import 'styles_harness.dart';

const _l10n = ZukkoChatL10n();

class _Capture implements VoiceCapture {
  StreamController<Uint8List>? audio;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async =>
      (audio = StreamController<Uint8List>()).stream;

  @override
  Future<void> stop() async => audio?.close();

  @override
  Future<void> dispose() async {}
}

/// The chunk is loud: the level bars have something to show.
Uint8List _loud() {
  final d = ByteData(3200);
  for (var i = 0; i < 1600; i++) {
    d.setInt16(i * 2, i.isEven ? 9000 : -9000, Endian.little);
  }
  return d.buffer.asUint8List();
}

final _skip = Platform.isMacOS ? null : 'goldens are generated on macOS';

void main() {
  late _Capture capture;
  late List<VoiceRecording> recorded;

  setUp(() {
    capture = _Capture();
    recorded = [];
    VoiceRecorderController.debugCapture = () => capture;
  });
  tearDown(() => VoiceRecorderController.debugCapture = null);

  Widget host(
    ChatStyle style, {
    bool reduceMotion = false,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      backgroundColor: style.backgroundColor,
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Builder(
              builder: (context) => style.buildComposer(
                context,
                ChatComposerData(
                  onSend: (_) {},
                  onAttach: () {},
                  onVoiceRecorded: recorded.add,
                ),
                _l10n,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<TestGesture> hold(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byType(VoiceRecordButton)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump();
    return g;
  }

  for (final kind in ZukkoChatStyle.values) {
    group(kind.name, () {
      final style = kind.resolve(
        const ZukkoChatTheme(brightness: Brightness.light),
      );
      final hint = kind == ZukkoChatStyle.minimalClean
          ? _l10n.voiceCancelHint
          : _l10n.voiceSlideLeftToCancel;

      testWidgets('shows timer, hint and level bars; the timer runs', (
        tester,
      ) async {
        await tester.pumpWidget(host(style));
        expect(find.byKey(const ValueKey('voice-timer')), findsNothing);
        final g = await hold(tester);
        expect(find.byKey(const ValueKey('voice-timer')), findsOneWidget);
        expect(find.byKey(const ValueKey('voice-bars')), findsOneWidget);
        expect(find.byKey(const ValueKey('voice-dot')), findsOneWidget);
        expect(find.text(hint), findsOneWidget);
        expect(find.text('0:00'), findsOneWidget);
        capture.audio!.add(_loud());
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('0:02'), findsOneWidget);
        await g.up();
        await tester.pump();
        expect(recorded, hasLength(1));
        expect(find.byKey(const ValueKey('voice-timer')), findsNothing);
      });

      testWidgets('sliding past the threshold cancels', (tester) async {
        await tester.pumpWidget(host(style));
        final g = await hold(tester);
        capture.audio!.add(_loud());
        await tester.pump(const Duration(seconds: 2));
        await g.moveBy(const Offset(-100, 0));
        await tester.pump();
        expect(find.text(_l10n.voiceReleaseToCancel), findsOneWidget);
        await g.up();
        await tester.pump();
        expect(recorded, isEmpty);
        expect(find.byKey(const ValueKey('voice-timer')), findsNothing);
      });

      testWidgets('reduced motion: nothing loops', (tester) async {
        await tester.pumpWidget(host(style, reduceMotion: true));
        final g = await hold(tester);
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.byKey(const ValueKey('voice-bars')), findsOneWidget);
        await g.up();
        await tester.pumpAndSettle();
      });

      testWidgets('with motion the dot, hint and mic loop', (tester) async {
        await tester.pumpWidget(host(style));
        final g = await hold(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.hasRunningAnimations, isTrue);
        await g.up();
        await tester.pump();
      });

      testWidgets('disposed mid-recording: no timers or errors left', (
        tester,
      ) async {
        await tester.pumpWidget(host(style));
        final g = await hold(tester);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
        await g.up();
      });

      testWidgets('announces recording and shows the elapsed time', (
        tester,
      ) async {
        final sem = tester.ensureSemantics();
        await tester.pumpWidget(host(style));
        final g = await hold(tester);
        await tester.pump(const Duration(seconds: 2));
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(_l10n.voiceRecordingLabel)),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('0:02'), findsOneWidget);
        await g.up();
        await tester.pump();
        sem.dispose();
      });

      testWidgets('fits 320 dp at text scale 1.3, mic >= 48 dp', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(style, textScale: 1.3));
        final g = await hold(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(VoiceMicRecording)).shortestSide,
          greaterThanOrEqualTo(48),
        );
        await g.up();
        await tester.pump();
      });

      for (final b in Brightness.values) {
        testWidgets('golden ${b.name}', (tester) async {
          tester.view.physicalSize = const Size(390, 220);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final s = kind.resolve(ZukkoChatTheme(brightness: b));
          await tester.pumpWidget(
            frame(
              ThemeData(brightness: b),
              s.backgroundColor,
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Builder(
                      builder: (context) => s.buildComposer(
                        context,
                        ChatComposerData(
                          onSend: (_) {},
                          onAttach: () {},
                          onVoiceRecorded: recorded.add,
                        ),
                        _l10n,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final g = await hold(tester);
          await expectLater(
            find.byKey(const ValueKey('shot')),
            matchesGoldenFile('goldens/${kind.name}_${b.name}_recording.png'),
          );
          await g.up();
          await tester.pump();
        }, skip: _skip != null);
      }
    });
  }
}
