import 'dart:async';
import 'dart:typed_data';

import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCapture implements VoiceCapture {
  bool permission = true;
  final log = <String>[];
  StreamController<Uint8List>? audio;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    log.add('start $sampleRate');
    audio = StreamController<Uint8List>();
    return audio!.stream;
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    await audio?.close();
  }

  @override
  Future<void> dispose() async => log.add('dispose');
}

void main() {
  late _FakeCapture capture;
  late List<VoiceRecording> recorded;
  late List<VoiceRecorderIssue> issues;
  late VoiceRecorderController recorder;

  setUp(() {
    capture = _FakeCapture();
    recorded = [];
    issues = [];
    recorder = VoiceRecorderController(
      onRecorded: recorded.add,
      onIssue: issues.add,
      capture: () => capture,
    );
  });

  test('hold, speak, release: a WAV recording with its duration', () {
    fakeAsync((async) {
      unawaited(recorder.start());
      async.flushMicrotasks();
      capture.audio!.add(Uint8List.fromList([1, 2, 3, 4]));
      async.elapse(const Duration(seconds: 3));
      expect(recorder.elapsed, const Duration(seconds: 3));
      unawaited(recorder.finish());
      async.flushMicrotasks();

      final r = recorded.single;
      expect(r.duration, const Duration(seconds: 3));
      expect(r.file.name, endsWith('.wav'));
      expect(r.file.isAudio, isTrue);
      final bytes = r.file.bytes!;
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(bytes.length, 44 + 4);
      expect(capture.log, ['start 16000', 'stop']);
      expect(recorder.isRecording, isFalse);
    });
  });

  test('slide to cancel, or too short: nothing is sent', () {
    fakeAsync((async) {
      unawaited(recorder.start());
      async.flushMicrotasks();
      capture.audio!.add(Uint8List(2));
      async.elapse(const Duration(seconds: 2));
      recorder.armCancel(true);
      unawaited(recorder.finish());
      async.flushMicrotasks();

      unawaited(recorder.start());
      async.flushMicrotasks();
      unawaited(recorder.finish());
      async.flushMicrotasks();

      expect(recorded, isEmpty);
    });
  });

  test('stops by itself at the maximum duration', () {
    fakeAsync((async) {
      unawaited(recorder.start());
      async.flushMicrotasks();
      capture.audio!.add(Uint8List(2));
      async.elapse(
        VoiceRecorderController.maxDuration + const Duration(seconds: 5),
      );

      expect(recorded.single.duration, VoiceRecorderController.maxDuration);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('refused microphone: reported, nothing recorded', () {
    fakeAsync((async) {
      capture.permission = false;
      unawaited(recorder.start());
      async.flushMicrotasks();

      expect(issues, [VoiceRecorderIssue.permissionDenied]);
      expect(recorder.isRecording, isFalse);
      expect(capture.log, isEmpty);
    });
  });

  test('released while the permission was asked: not left recording', () {
    fakeAsync((async) {
      unawaited(recorder.start());
      unawaited(recorder.finish());
      async.flushMicrotasks();

      expect(recorder.isRecording, isFalse);
      expect(capture.log, ['start 16000', 'stop']);
    });
  });
}
