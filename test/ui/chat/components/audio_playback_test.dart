import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';

class _FakeEngine implements AudioEngine {
  final playing = StreamController<bool>.broadcast(sync: true);
  final position = StreamController<Duration>.broadcast(sync: true);
  final duration = StreamController<Duration?>.broadcast(sync: true);
  final completed = StreamController<void>.broadcast(sync: true);
  final loads = <String, Completer<Duration?>>{};
  final log = <String>[];

  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<Duration> get positionStream => position.stream;
  @override
  Stream<Duration?> get durationStream => duration.stream;
  @override
  Stream<void> get completedStream => completed.stream;

  @override
  Future<Duration?> setUrl(String url) {
    log.add('load $url');
    return (loads[url] = Completer<Duration?>()).future;
  }

  @override
  Future<Duration?> setFilePath(String path) async {
    log.add('file $path');
    return const Duration(seconds: 5);
  }

  @override
  Future<void> play() async => log.add('play');
  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> seek(Duration p) async => log.add('seek ${p.inSeconds}');
  @override
  Future<void> dispose() async => log.add('dispose');
}

void main() {
  const a = 'https://c.test/a.wav';
  const b = 'https://c.test/b.wav';
  late _FakeEngine engine;
  late AudioPlaybackController playback;

  setUp(() {
    engine = _FakeEngine();
    playback = AudioPlaybackController(engine: () => engine);
  });

  tearDown(() => playback.dispose());

  test('a position tick notifies only the message that plays (U17)', () async {
    final forA = playback.watch(a);
    final forB = playback.watch(b);
    var aTicks = 0, bTicks = 0;
    forA.addListener(() => aTicks++);
    forB.addListener(() => bTicks++);

    final toggle = playback.toggle(a);
    engine.loads[a]!.complete(const Duration(seconds: 10));
    await toggle;
    engine.playing.add(true);
    final aBefore = aTicks;

    for (var s = 1; s <= 5; s++) {
      engine.position.add(Duration(seconds: s));
    }
    expect(aTicks - aBefore, 5);
    expect(bTicks, 0);
    expect(forA.value.progress, 0.5);
    expect(forA.value.playing, isTrue);
    expect(forB.value, AudioPlaybackView.idle);
  });

  test('switching message resets the old one and starts the new', () async {
    final forA = playback.watch(a);
    final first = playback.toggle(a);
    engine.loads[a]!.complete(const Duration(seconds: 10));
    await first;
    engine.playing.add(true);

    final second = playback.toggle(b);
    engine.loads[b]!.complete(const Duration(seconds: 4));
    await second;
    expect(forA.value, AudioPlaybackView.idle);
    expect(playback.watch(b).value.length, const Duration(seconds: 4));
  });

  test(
    'a load that finishes late does not overwrite the newer one (U30)',
    () async {
      final first = playback.toggle(a);
      final second = playback.toggle(b);
      engine.loads[b]!.complete(const Duration(seconds: 4));
      await second;
      engine.loads[a]!.complete(const Duration(seconds: 99)); // late
      await first;

      expect(playback.watch(b).value.length, const Duration(seconds: 4));
      expect(playback.watch(a).value.length, isNull);
      // only the newer one was played
      expect(engine.log.where((l) => l == 'play'), hasLength(1));
    },
  );

  test('local paths cannot be played', () async {
    await playback.toggle('/data/user/0/x.wav');
    expect(engine.log, isEmpty);
  });

  group('local recordings', () {
    late Directory dir;
    late String file;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('zukko_audio');
      file = '${dir.path}/note.m4a';
      File(file).writeAsBytesSync([0]);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('an existing file plays through the file API, not setUrl', () async {
      expect(AudioPlaybackController.canPlay(file), isTrue);
      await playback.toggle(file);
      expect(engine.log, ['file $file', 'play']);
    });

    test('http goes to setUrl', () async {
      final t = playback.toggle(a);
      engine.loads[a]!.complete(null);
      await t;
      expect(engine.log.first, 'load $a');
    });

    test('a missing file is not playable and does nothing', () async {
      final missing = '${dir.path}/gone.m4a';
      expect(AudioPlaybackController.canPlay(missing), isFalse);
      await playback.toggle(missing);
      await playback.seek(missing, 0.5);
      expect(engine.log, isEmpty);
    });

    test('release stops the current source and idles its watcher', () async {
      await playback.toggle(file);
      engine.playing.add(true);
      expect(playback.watch(file).value.playing, isTrue);
      playback.release(file);
      expect(engine.log.last, 'pause');
      expect(playback.watch(file).value, AudioPlaybackView.idle);
      engine.log.clear();
      playback.release(file); // not current any more: no-op
      expect(engine.log, isEmpty);
    });
  });

  group('length before play', () {
    test(
      'a known length is shown at once and beats the engine after play',
      () async {
        final engine = _FakeEngine();
        final c = AudioPlaybackController(engine: () => engine);
        addTearDown(c.dispose);
        const url = 'https://cdn.test/v.wav';

        c.prime(url, const Duration(seconds: 3));
        expect(c.watch(url).value.length, const Duration(seconds: 3));

        final toggle = c.toggle(url);
        engine.loads[url]!.complete(const Duration(minutes: 5));
        await toggle;
        engine.duration.add(const Duration(minutes: 5));
        engine.position.add(const Duration(milliseconds: 1500));

        expect(c.watch(url).value.length, const Duration(seconds: 3));
        expect(c.watch(url).value.progress, 0.5);
      },
    );

    test('an unknown length is read from the remote file head', () async {
      final c = AudioPlaybackController(
        engine: _FakeEngine.new,
        lengthProbe: (_) async => const Duration(seconds: 9),
      );
      addTearDown(c.dispose);
      const url = 'https://cdn.test/v.wav';
      final seen = c.watch(url);

      c.prime(url, Duration.zero);
      await pumpEventQueue();

      expect(seen.value.length, const Duration(seconds: 9));
    });
  });
}
