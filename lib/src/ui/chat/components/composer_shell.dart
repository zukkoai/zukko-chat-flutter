import 'package:flutter/material.dart';

import '../../../core/zukko_chat_upload.dart';
import 'voice_recorder_controller.dart';

/// The server counts code points (Ruby `String#length`), not UTF-16 units.
bool _overLimit(String s) =>
    s.length > ZukkoChatUpload.maxMessageLength &&
    s.runes.length > ZukkoChatUpload.maxMessageLength;

/// What a style's composer draws with; owned by [ComposerShell].
class ComposerHandle {
  final TextEditingController text;
  final FocusNode focusNode;

  /// There is text to send, and it is within the server limit.
  final bool canSend;

  /// Sends the trimmed text and clears the field.
  final VoidCallback send;

  /// Null when voice messages are off.
  final VoiceRecorderController? recorder;

  /// Keeps the mic (and its running press) alive when a style moves it to
  /// the recording layout.
  final GlobalKey? micKey;

  const ComposerHandle({
    required this.text,
    required this.focusNode,
    required this.canSend,
    required this.send,
    required this.recorder,
    this.micKey,
  });

  bool get isRecording => recorder?.isRecording ?? false;
}

/// Composer behaviour shared by every style: the text field state, sending
/// and hold-to-record. The style only lays out [builder].
class ComposerShell extends StatefulWidget {
  final ValueChanged<String> onSend;

  /// Called on every edit that leaves text in the field.
  final VoidCallback? onTyping;

  /// Null turns voice messages off.
  final ValueChanged<VoiceRecording>? onVoiceRecorded;
  final ValueChanged<VoiceRecorderIssue>? onVoiceIssue;

  /// Called when an edit takes the text over
  /// [ZukkoChatUpload.maxMessageLength]; sending stays off until it is shorter.
  final VoidCallback? onTooLong;
  final Widget Function(BuildContext context, ComposerHandle handle) builder;

  const ComposerShell({
    super.key,
    required this.onSend,
    required this.builder,
    this.onTyping,
    this.onVoiceRecorded,
    this.onVoiceIssue,
    this.onTooLong,
  });

  @override
  State<ComposerShell> createState() => _ComposerShellState();
}

class _ComposerShellState extends State<ComposerShell> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  VoiceRecorderController? _recorder;
  final _micKey = GlobalKey(debugLabel: 'composer-mic');
  bool _canSend = false;
  bool _tooLong = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    _syncRecorder();
  }

  @override
  void didUpdateWidget(ComposerShell old) {
    super.didUpdateWidget(old);
    _syncRecorder();
  }

  /// One recorder for the composer's lifetime; only its callbacks follow
  /// rebuilds (the parent creates new closures every build).
  void _syncRecorder() {
    final onRecorded = widget.onVoiceRecorded;
    final recorder = _recorder;
    void onIssue(VoiceRecorderIssue issue) => widget.onVoiceIssue?.call(issue);
    if (onRecorded == null) {
      recorder?.dispose();
      _recorder = null;
    } else if (recorder == null) {
      _recorder = VoiceRecorderController(
        onRecorded: onRecorded,
        onIssue: onIssue,
      )..addListener(_rebuild);
    } else {
      recorder
        ..onRecorded = onRecorded
        ..onIssue = onIssue;
    }
  }

  void _rebuild() => setState(() {});

  void _onTextChanged() {
    final text = _text.text;
    final trimmed = text.trim();
    final tooLong = _overLimit(trimmed);
    final canSend = trimmed.isNotEmpty && !tooLong;
    if (tooLong && !_tooLong) widget.onTooLong?.call();
    _tooLong = tooLong;
    // The controller also notifies on caret / selection moves: only an edit
    // counts as typing.
    if (trimmed.isNotEmpty && text != _lastText) widget.onTyping?.call();
    _lastText = text;
    if (canSend != _canSend) setState(() => _canSend = canSend);
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty || _overLimit(text)) return;
    widget.onSend(text);
    _text.clear();
  }

  @override
  void dispose() {
    _recorder?.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    ComposerHandle(
      text: _text,
      focusNode: _focus,
      canSend: _canSend,
      send: _send,
      recorder: _recorder,
      micKey: _micKey,
    ),
  );
}

/// The composer's text field: no decoration of its own, the style draws the
/// container around it.
class ComposerTextField extends StatelessWidget {
  final ComposerHandle handle;
  final String hintText;
  final TextStyle style;
  final TextStyle hintStyle;
  final Color cursorColor;
  final Brightness keyboardAppearance;
  final EdgeInsetsGeometry padding;

  const ComposerTextField({
    super.key,
    required this.handle,
    required this.hintText,
    required this.style,
    required this.hintStyle,
    required this.cursorColor,
    required this.keyboardAppearance,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: handle.text,
    focusNode: handle.focusNode,
    style: style,
    cursorColor: cursorColor,
    keyboardAppearance: keyboardAppearance,
    textCapitalization: TextCapitalization.sentences,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    minLines: 1,
    maxLines: 5,
    decoration: InputDecoration(
      isCollapsed: true,
      border: InputBorder.none,
      hintText: hintText,
      hintStyle: hintStyle,
      contentPadding: padding,
    ),
  );
}
