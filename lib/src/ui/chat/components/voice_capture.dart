import 'dart:typed_data';

import 'package:record/record.dart';

/// Microphone access; [RecordVoiceCapture] in the app, a fake in tests.
abstract interface class VoiceCapture {
  /// Asks for the permission when needed.
  Future<bool> hasPermission();

  /// Raw 16-bit PCM chunks until [stop].
  Future<Stream<Uint8List>> start({required int sampleRate});
  Future<void> stop();
  Future<void> dispose();
}

/// [VoiceCapture] on the `record` package (Android, iOS, web, desktop).
class RecordVoiceCapture implements VoiceCapture {
  final _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) =>
      _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
