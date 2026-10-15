import 'package:flutter/material.dart';

import 'voice_recorder.dart';

/// What a style's composer draws with; owned by [ComposerShell].
class ComposerHandle {
  final TextEditingController text;
  final FocusNode focusNode;

  /// There is text to send.
  final bool canSend;

  /// Sends the trimmed text and clears the field.
  final VoidCallback send;

  /// Null when voice messages are off.
  final VoiceRecorderController? recorder;

  const ComposerHandle({
    required this.text,
    required this.focusNode,
    required this.canSend,
    required this.send,
    required this.recorder,
  });

  bool get isRecording => recorder?.isRecording ?? false;
}

/// Composer behaviour shared by every style: the text field state, sending
/// and hold-to-record. The style only lays out [builder].
class ComposerShell extends StatefulWidget {
  final ValueChanged<String> onSend;

  /// Null turns voice messages off.
  final ValueChanged<VoiceRecording>? onVoiceRecorded;
  final ValueChanged<VoiceRecorderIssue>? onVoiceIssue;
  final Widget Function(BuildContext context, ComposerHandle handle) builder;

  const ComposerShell({
    super.key,
    required this.onSend,
    required this.builder,
    this.onVoiceRecorded,
    this.onVoiceIssue,
  });

  @override
  State<ComposerShell> createState() => _ComposerShellState();
}

class _ComposerShellState extends State<ComposerShell> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  VoiceRecorderController? _recorder;
  bool _canSend = false;

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
    final canSend = _text.text.trim().isNotEmpty;
    if (canSend != _canSend) setState(() => _canSend = canSend);
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
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
