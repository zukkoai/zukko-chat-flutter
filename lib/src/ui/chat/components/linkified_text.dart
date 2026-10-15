import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'link_launcher.dart';

/// Message text with tappable links. Taps outside a link reach the message.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final link in findLinks(text)) {
      if (link.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, link.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => unawaited(openExternalLink(link.uri));
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: text.substring(link.start, link.end),
          style: widget.linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = link.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
