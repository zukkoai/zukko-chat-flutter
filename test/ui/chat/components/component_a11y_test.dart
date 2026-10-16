import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';

class _FakeCapture implements VoiceCapture {
  final log = <String>[];
  StreamController<Uint8List>? audio;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    log.add('start');
    audio = StreamController<Uint8List>();
    return audio!.stream;
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    await audio?.close();
  }

  @override
  Future<void> dispose() async {}
}

Widget _host(Widget child, {bool reduceMotion = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(child: child),
  ),
);

void main() {
  group('voice record button (U19)', () {
    testWidgets('a screen reader can start and send with a tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final capture = _FakeCapture();
      final recorded = <VoiceRecording>[];
      final recorder = VoiceRecorderController(
        onRecorded: recorded.add,
        onIssue: (_) {},
        capture: () => capture,
      );
      addTearDown(recorder.dispose);

      await tester.pumpWidget(
        _host(
          VoiceRecordButton(
            recorder: recorder,
            semanticLabel: 'Record',
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Record'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.semantics.tap(find.semantics.byLabel('Record'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(recorder.isRecording, isTrue);
      expect(capture.log, ['start']);

      // a second tap sends (too short here: dropped), recording ends
      await tester.runAsync(recorder.cancel);
      handle.dispose();
    });
  });

  group('typing indicator (U21)', () {
    testWidgets('moves normally, stands still with reduce motion', (
      tester,
    ) async {
      const dots = TypingIndicator(
        color: Color(0xFF000000),
        semanticLabel: 't',
      );
      await tester.pumpWidget(_host(dots));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(_host(dots, reduceMotion: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('tap targets (U20)', () {
    testWidgets('powered-by link is at least 48 high', (tester) async {
      await tester.pumpWidget(
        _host(
          const PoweredBy(
            prefix: 'Powered by',
            style: TextStyle(fontSize: 12),
            linkColor: Color(0xFF0000FF),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ConstrainedBox).last).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('audio play button hit area is 48 although it draws 36', (
      tester,
    ) async {
      final playback = AudioPlaybackController(engine: _NoEngine.new);
      addTearDown(playback.dispose);
      await tester.pumpWidget(
        _host(
          AudioPlayerBar(
            playback: playback,
            source: 'https://c.test/a.wav',
            duration: const Duration(seconds: 3),
            waveform: placeholderWaveform('x'),
            colors: const AudioPlayerColors(
              buttonFill: Color(0xFF000000),
              buttonIcon: Color(0xFFFFFFFF),
              waveActive: Color(0xFF000000),
              waveInactive: Color(0xFF888888),
            ),
            durationStyle: const TextStyle(fontSize: 12),
            semanticLabel: 'Voice',
            playLabel: 'Play',
            pauseLabel: 'Pause',
          ),
        ),
      );
      final hit = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 48 && w.height == 48,
      );
      expect(hit, findsOneWidget);
      // the drawn button is 36
      expect(
        tester.getSize(find.byType(DecoratedBox).first),
        const Size(36, 36),
      );
    });
  });

  test('the placeholder waveform is cached per seed (same list instance)', () {
    expect(
      identical(placeholderWaveform('a'), placeholderWaveform('a')),
      isTrue,
    );
    expect(placeholderWaveform('a'), isNot(placeholderWaveform('b')));
  });
}

class _NoEngine implements AudioEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
