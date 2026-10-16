import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// The audio player behind [AudioPlaybackController]: `just_audio` in the
/// app, a fake in tests.
abstract interface class AudioEngine {
  /// True while sound is playing (false once the track completed).
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;

  /// Fires when the track played to its end.
  Stream<void> get completedStream;

  /// Loads [url]; the track length when known.
  Future<Duration?> setUrl(String url);

  /// Loads the local file at [path]; the track length when known.
  Future<Duration?> setFilePath(String path);

  /// Completes when playback stops, so callers must not await it.
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// [AudioEngine] on `just_audio`.
class JustAudioEngine implements AudioEngine {
  final _player = AudioPlayer();

  @override
  Stream<bool> get playingStream => _player.playerStateStream.map(
    (s) => s.playing && s.processingState != ProcessingState.completed,
  );

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<void> get completedStream => _player.playerStateStream.where(
    (s) => s.processingState == ProcessingState.completed,
  );

  @override
  Future<Duration?> setUrl(String url) => _player.setUrl(url);

  @override
  Future<Duration?> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
