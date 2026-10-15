import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';

import '../../../core/chatwoot_upload.dart';
import '../../../shared/sdk_log.dart';

/// A finished voice message, ready to send.
@immutable
class VoiceRecording {
  /// WAV audio (16 kHz, mono, 16-bit).
  final ChatwootUpload file;
  final Duration duration;

  const VoiceRecording(this.file, this.duration);
}

/// Why a recording did not happen.
enum VoiceRecorderIssue { permissionDenied, failed }

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

/// Hold-to-record: asks for the microphone, records PCM, keeps time, lets
/// the user arm cancel, and hands a WAV [VoiceRecording] to [onRecorded].
/// Shared by every style's composer.
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController({
    required this.onRecorded,
    required this.onIssue,
    VoiceCapture Function()? capture,
  }) : _createCapture = capture ?? RecordVoiceCapture.new;

  /// Kept current by the composer across rebuilds.
  ValueChanged<VoiceRecording> onRecorded;
  ValueChanged<VoiceRecorderIssue> onIssue;

  /// Recording stops on its own after this long (server limit).
  static const maxDuration = Duration(minutes: 5);

  /// Shorter recordings are dropped (an accidental long press).
  static const minDuration = Duration(seconds: 1);

  static const _sampleRate = 16000;
  static const _tick = Duration(seconds: 1);

  final VoiceCapture Function() _createCapture;
  VoiceCapture? _capture;
  StreamSubscription<Uint8List>? _audio;
  final _pcm = BytesBuilder(copy: false);
  Timer? _timer;
  bool _starting = false;
  bool _recording = false;
  bool _releasedWhileStarting = false;
  bool _cancelArmed = false;
  bool _disposed = false;
  Duration _elapsed = Duration.zero;

  bool get isRecording => _recording;

  /// Releasing now would cancel instead of sending.
  bool get willCancel => _cancelArmed;
  Duration get elapsed => _elapsed;

  Future<void> start() async {
    if (_starting || _recording || _disposed) return;
    _starting = true;
    _releasedWhileStarting = false;
    try {
      final capture = _capture ??= _createCapture();
      if (!await capture.hasPermission()) {
        _starting = false;
        if (!_disposed) onIssue(VoiceRecorderIssue.permissionDenied);
        return;
      }
      final stream = await capture.start(sampleRate: _sampleRate);
      _starting = false;
      if (_disposed || _releasedWhileStarting) {
        // The finger was lifted while the permission dialog was open.
        await capture.stop();
        return;
      }
      _pcm.clear();
      _audio = stream.listen(_pcm.add);
      _recording = true;
      _cancelArmed = false;
      _elapsed = Duration.zero;
      _timer = Timer.periodic(_tick, (_) => _onTick());
      notifyListeners();
    } catch (e) {
      sdkLog('voice recording failed: $e');
      _starting = false;
      if (!_disposed) onIssue(VoiceRecorderIssue.failed);
    }
  }

  void armCancel(bool armed) {
    if (!_recording || armed == _cancelArmed) return;
    _cancelArmed = armed;
    notifyListeners();
  }

  /// Ends the recording: sent unless cancel is armed or it is too short.
  Future<void> finish() async {
    if (_starting) {
      _releasedWhileStarting = true;
      return;
    }
    if (!_recording) return;
    final keep = !_cancelArmed && _elapsed >= minDuration;
    final duration = _elapsed;
    final pcm = await _stop();
    if (keep && pcm.isNotEmpty && !_disposed) {
      onRecorded(
        VoiceRecording(
          ChatwootUpload.bytes(
            name: 'voice-${DateTime.now().millisecondsSinceEpoch}.wav',
            bytes: wavFromPcm16(pcm, sampleRate: _sampleRate),
          ),
          duration,
        ),
      );
    }
  }

  /// Drops the recording.
  Future<void> cancel() async {
    if (_starting) {
      _releasedWhileStarting = true;
      return;
    }
    if (_recording) await _stop();
  }

  void _onTick() {
    _elapsed += _tick;
    if (_elapsed >= maxDuration) {
      unawaited(finish());
      return;
    }
    notifyListeners();
  }

  /// Stops capturing and returns the PCM recorded so far.
  Future<Uint8List> _stop() async {
    _timer?.cancel();
    _timer = null;
    _recording = false;
    _cancelArmed = false;
    _elapsed = Duration.zero;
    if (!_disposed) notifyListeners();
    try {
      await _capture?.stop();
    } catch (e) {
      sdkLog('voice recording stop failed: $e');
    }
    // Not awaited: `stop` already ended the stream, and the cancel future of
    // a finished subscription can stay pending (it blocked finish under
    // fakeAsync), which would hold back `onRecorded`.
    unawaited(_audio?.cancel());
    _audio = null;
    return _pcm.takeBytes();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    final capture = _capture;
    final audio = _audio;
    unawaited(() async {
      await audio?.cancel();
      await capture?.dispose();
    }());
    super.dispose();
  }
}

/// Wraps the microphone visual: long press records, sliding towards the
/// start edge by [cancelDistance] arms cancel, releasing sends.
class VoiceRecordButton extends StatelessWidget {
  final VoiceRecorderController recorder;
  final String semanticLabel;
  final double cancelDistance;
  final Widget child;

  const VoiceRecordButton({
    super.key,
    required this.recorder,
    required this.semanticLabel,
    required this.child,
    this.cancelDistance = 72,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => unawaited(recorder.start()),
        onLongPressMoveUpdate: (details) {
          final towardsStart = rtl
              ? details.offsetFromOrigin.dx
              : -details.offsetFromOrigin.dx;
          recorder.armCancel(towardsStart > cancelDistance);
        },
        onLongPressEnd: (_) => unawaited(recorder.finish()),
        onLongPressCancel: () => unawaited(recorder.cancel()),
        child: child,
      ),
    );
  }
}

/// Replaces the text field while recording: timer and the cancel hint.
class VoiceRecordingBar extends StatelessWidget {
  final VoiceRecorderController recorder;
  final String cancelHint;
  final String releaseToCancel;
  final TextStyle timerStyle;
  final TextStyle hintStyle;
  final Color dotColor;

  const VoiceRecordingBar({
    super.key,
    required this.recorder,
    required this.cancelHint,
    required this.releaseToCancel,
    required this.timerStyle,
    required this.hintStyle,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Text(
        formatDuration(recorder.elapsed),
        style: timerStyle.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          recorder.willCancel ? releaseToCancel : cancelHint,
          style: hintStyle,
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// `m:ss`, e.g. `0:09`, `12:30`.
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// [pcm] (16-bit little-endian) wrapped in a WAV header.
Uint8List wavFromPcm16(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + pcm.length, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, channels * bitsPerSample ~/ 8, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}
