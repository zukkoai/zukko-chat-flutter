import 'dart:async';
import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/sdk_log.dart';
import '../../../shared/url_policy.dart';
import '../../../shared/wav.dart';
import 'audio_engine.dart';

/// What one voice message shows: playing or not, how far, how long.
@immutable
class AudioPlaybackView {
  final bool playing;

  /// 0..1; 0 unless this message is the current one.
  final double progress;

  /// Length once loaded, else null.
  final Duration? length;

  const AudioPlaybackView({
    this.playing = false,
    this.progress = 0,
    this.length,
  });

  static const idle = AudioPlaybackView();

  @override
  bool operator ==(Object other) =>
      other is AudioPlaybackView &&
      playing == other.playing &&
      progress == other.progress &&
      length == other.length;

  @override
  int get hashCode => Object.hash(playing, progress, length);
}

/// Plays the chat's voice messages, one at a time: starting another one
/// stops the current. One per chat view, shared by every style.
///
/// Each message listens to its own [watch]er, so a position tick rebuilds
/// only the message that is playing.
class AudioPlaybackController {
  AudioPlaybackController({
    AudioEngine Function()? engine,
    Future<Duration?> Function(String url)? lengthProbe,
  }) : _createEngine = engine ?? JustAudioEngine.new,
       _probe = lengthProbe ?? _probeWavHead;

  final Future<Duration?> Function(String url) _probe;

  /// Lengths known without playing: a recording's own, or a WAV header read.
  /// They win over the engine's, which streaming sources can get wrong.
  final _known = <String, Duration>{};
  final _probing = <String>{};

  /// Reads the first bytes of a remote WAV; null for other formats / errors.
  /// A fresh client: no auth headers, https only, no redirects, 10 s, and at
  /// most [_probeBytes] are read even if the server ignores the Range.
  static const _probeBytes = 4096;
  static Future<Duration?> _probeWavHead(String url) async {
    if (!isHttpsUrl(url)) return null;
    final cancel = CancelToken();
    try {
      final res = await Dio().get<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=0-${_probeBytes - 1}'},
          followRedirects: false,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final head = <int>[];
      await for (final chunk in res.data!.stream) {
        head.addAll(chunk);
        if (head.length >= _probeBytes) break;
      }
      cancel.cancel();
      return wavDuration(Uint8List.fromList(head));
    } catch (_) {
      sdkLog('wav length probe failed', level: SdkLogLevel.warning);
      return null;
    }
  }

  /// Shows [source]'s length before it is played: [known] when given (own
  /// recording), else read from the file's header when it is a remote WAV.
  void prime(String source, Duration? known) {
    if (_disposed) return;
    if (known != null && known > Duration.zero) {
      // Called while building: the bubble reads it in the same build, so no
      // notification (it would mark a builder dirty mid-build).
      _known[source] = known;
    } else if (isHttpsUrl(source) &&
        !_known.containsKey(source) &&
        _probing.add(source)) {
      unawaited(
        _probe(source).then((d) {
          if (d != null && d > Duration.zero) _setKnown(source, d);
        }),
      );
    }
  }

  void _setKnown(String source, Duration d) {
    if (_known[source] == d) return;
    _known[source] = d;
    if (_disposed) return;
    _watchers[source]?.value = _viewOf(source);
  }

  final AudioEngine Function() _createEngine;
  AudioEngine? _engine;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _watchers = <String, ValueNotifier<AudioPlaybackView>>{};

  String? _source;
  String? _published;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  /// Bumped by every load: a load that finished late is dropped.
  int _loadId = 0;

  /// http(s) sources, and (off the web) a local recording that still exists.
  static bool canPlay(String source) =>
      isHttpUrl(source) || (!kIsWeb && File(source).existsSync());

  /// Stops [source] if it is the current one and drops its state. Called when
  /// a bubble's source changes (local file -> server URL after the upload):
  /// the note stops rather than playing on with no controls.
  void release(String source) {
    if (_disposed || _source != source) return;
    _loadId++;
    unawaited(_engine?.pause());
    _source = null;
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _publish();
  }

  /// The state of [source], updated only when it changes.
  ValueListenable<AudioPlaybackView> watch(String source) =>
      _watchers.putIfAbsent(source, () => ValueNotifier(_viewOf(source)));

  AudioPlaybackView _viewOf(String source) {
    final known = _known[source];
    if (_source != source) return AudioPlaybackView(length: known);
    final length = known ?? _duration;
    final progress = length <= Duration.zero
        ? 0.0
        : (_position.inMilliseconds / length.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    return AudioPlaybackView(
      playing: _playing,
      progress: progress,
      length: length > Duration.zero ? length : null,
    );
  }

  /// Pushes the new state to the message that was and the one that is
  /// current; every other message is idle before and after.
  void _publish() {
    if (_disposed) return;
    for (final s in {_published, _source}) {
      if (s != null) _watchers[s]?.value = _viewOf(s);
    }
    _published = _source;
  }

  /// Plays [source], or pauses / resumes it when it is the current one.
  Future<void> toggle(String source) async {
    if (_disposed || !canPlay(source)) return;
    if (_source == source) {
      final engine = _engine!;
      if (_playing) {
        await engine.pause();
      } else {
        unawaited(engine.play());
      }
      return;
    }
    if (await _load(source)) unawaited(_engine!.play());
  }

  /// Jumps to [fraction] (0..1) of [source]. Another message is loaded and
  /// played from there; the current one keeps playing or paused.
  Future<void> seek(String source, double fraction) async {
    if (_disposed || !canPlay(source)) return;
    final switching = _source != source;
    if (switching && !await _load(source)) return;
    final length = _known[source] ?? _duration;
    if (length <= Duration.zero) return;
    final target = length * fraction.clamp(0.0, 1.0);
    _position = target;
    _publish();
    await _engine!.seek(target);
    if (switching) unawaited(_engine!.play());
  }

  /// Makes [source] the current one; false when it cannot be loaded or a
  /// later load replaced it meanwhile.
  Future<bool> _load(String source) async {
    final engine = _ensureEngine();
    final id = ++_loadId;
    _source = source;
    _position = Duration.zero;
    _duration = Duration.zero;
    _playing = false;
    _publish();
    try {
      final length = isHttpUrl(source)
          ? await engine.setUrl(source)
          : await engine.setFilePath(source);
      if (id != _loadId || _disposed) return false;
      if (length != null) {
        _duration = length;
        _publish();
      }
      return true;
    } catch (e) {
      sdkLog('audio playback failed: $e', level: SdkLogLevel.warning);
      if (id == _loadId && !_disposed) {
        _source = null;
        _playing = false;
        _publish();
      }
      return false;
    }
  }

  /// Created on first use, so a chat without voice messages never touches
  /// the audio plugin.
  AudioEngine _ensureEngine() {
    final existing = _engine;
    if (existing != null) return existing;
    final engine = _createEngine();
    _subscriptions.addAll([
      engine.playingStream.listen((p) {
        _playing = p;
        _publish();
      }),
      engine.positionStream.listen((p) {
        _position = p;
        _publish();
      }),
      engine.durationStream.listen((d) {
        _duration = d ?? Duration.zero;
        _publish();
      }),
      engine.completedStream.listen(
        (_) =>
            unawaited(engine.pause().then((_) => engine.seek(Duration.zero))),
      ),
    ]);
    return _engine = engine;
  }

  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_engine?.dispose());
    for (final w in _watchers.values) {
      w.dispose();
    }
    _watchers.clear();
  }
}
