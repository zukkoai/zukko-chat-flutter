import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../shared/sdk_log.dart';

/// Plays the chat's voice messages, one at a time: starting another one
/// stops the current. One per chat view, shared by every style.
class AudioPlaybackController extends ChangeNotifier {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];

  String? _source;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  /// Only http(s) sources can be played (local previews cannot).
  static bool canPlay(String source) =>
      source.startsWith('https://') || source.startsWith('http://');

  bool isPlaying(String source) => _source == source && _playing;

  /// 0..1 of [source]; 0 when it is not the current one.
  double progressOf(String source) {
    if (_source != source || _duration <= Duration.zero) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Length of [source] once loaded, else null.
  Duration? durationOf(String source) =>
      _source == source && _duration > Duration.zero ? _duration : null;

  /// Plays [source], or pauses / resumes it when it is the current one.
  Future<void> toggle(String source) async {
    if (_disposed || !canPlay(source)) return;
    if (_source == source) {
      final player = _player!;
      if (_playing) {
        await player.pause();
      } else {
        unawaited(player.play());
      }
      return;
    }
    if (await _load(source)) unawaited(_player!.play());
  }

  /// Jumps to [fraction] (0..1) of [source]. Another message is loaded and
  /// played from there; the current one keeps playing or paused.
  Future<void> seek(String source, double fraction) async {
    if (_disposed || !canPlay(source)) return;
    final switching = _source != source;
    if (switching && !await _load(source)) return;
    final length = _duration;
    if (length <= Duration.zero) return;
    final target = length * fraction.clamp(0.0, 1.0);
    _update(() => _position = target);
    await _player!.seek(target);
    if (switching) unawaited(_player!.play());
  }

  /// Makes [source] the current one; false when it cannot be loaded.
  Future<bool> _load(String source) async {
    final player = _ensurePlayer();
    _source = source;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    try {
      // play() completes only when playback stops: callers do not await it.
      final length = await player.setUrl(source);
      if (length != null) _update(() => _duration = length);
      return !_disposed;
    } catch (e) {
      sdkLog('audio playback failed: $e');
      if (!_disposed) {
        _source = null;
        _playing = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Created on first use, so a chat without voice messages never touches
  /// the audio plugin.
  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _subscriptions.addAll([
      player.playerStateStream.listen(_onState),
      player.positionStream.listen((p) => _update(() => _position = p)),
      player.durationStream.listen(
        (d) => _update(() => _duration = d ?? Duration.zero),
      ),
    ]);
    return _player = player;
  }

  void _onState(PlayerState state) {
    final completed = state.processingState == ProcessingState.completed;
    _update(() => _playing = state.playing && !completed);
    if (completed) {
      final player = _player!;
      unawaited(player.pause().then((_) => player.seek(Duration.zero)));
    }
  }

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player?.dispose());
    super.dispose();
  }
}
