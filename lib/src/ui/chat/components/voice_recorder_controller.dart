import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../core/zukko_chat_upload.dart';
import '../../../shared/sdk_log.dart';
import '../../../shared/wav.dart';
import 'voice_capture.dart';

/// A finished voice message, ready to send.
@immutable
class VoiceRecording {
  /// WAV audio (16 kHz, mono, 16-bit).
  final ZukkoChatUpload file;
  final Duration duration;

  const VoiceRecording(this.file, this.duration);
}

/// Why a recording did not happen.
enum VoiceRecorderIssue { permissionDenied, failed }

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
      sdkLog('voice recording failed: $e', level: SdkLogLevel.warning);
      _starting = false;
      if (!_disposed) onIssue(VoiceRecorderIssue.failed);
    }
  }

  /// Starts, or sends when already recording (the screen reader path).
  Future<void> toggle() => _recording ? finish() : start();

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
          ZukkoChatUpload.bytes(
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
      sdkLog('voice recording stop failed: $e', level: SdkLogLevel.warning);
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
