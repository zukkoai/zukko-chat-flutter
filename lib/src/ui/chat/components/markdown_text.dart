import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

import 'link_launcher.dart';
import 'linkified_text.dart';

/// Parses [text] as GitHub-flavoured Markdown. Raw HTML stays text nodes: the
/// renderer below never interprets it.
List<md.Node> parseMarkdown(String text) => md.Document(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parseLines(text.replaceAll('\r\n', '\n').split('\n'));

/// Whether [nodes] is a single plain paragraph (text and bare links only),
/// i.e. text that shows exactly as it was typed.
bool _isPlain(List<md.Node> nodes, String text) {
  if (nodes.length != 1) return false;
  final p = nodes.first;
  if (p is! md.Element || p.tag != 'p') return false;
  for (final c in p.children ?? const <md.Node>[]) {
    if (c is md.Text) continue;
    if (c is md.Element &&
        c.tag == 'a' &&
        c.textContent == c.attributes['href']) {
      continue;
    }
    if (c is md.Element &&
        c.tag == 'a' &&
        c.textContent.toLowerCase().startsWith('www.')) {
      continue;
    }
    return false;
  }
  return p.textContent == text.trim();
}

const _blockTags = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'pre',
  'blockquote',
  'hr',
  'table',
};

/// Incoming message text rendered from Markdown with the style's own text
/// style. Parsed once per text. Links go through the SDK's link policy
/// ([parseLink]: http(s) only) and [onOpen].
class MarkdownText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  /// Opens a tapped link; defaults to the SDK's external link opener.
  final void Function(Uri uri)? onOpen;

  const MarkdownText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    this.onOpen,
  });

  @override
  State<MarkdownText> createState() => _MarkdownTextState();
}

class _MarkdownTextState extends State<MarkdownText> {
  final _recognizers = <TapGestureRecognizer>[];
  late List<md.Node> _nodes;
  late bool _plain;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(MarkdownText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _parse();
  }

  void _parse() {
    _nodes = parseMarkdown(widget.text);
    _plain = _isPlain(_nodes, widget.text);
  }

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

  void _open(Uri uri) =>
      (widget.onOpen ?? (u) => unawaited(openExternalLink(u)))(uri);

  /// [children] as one rich text in [style].
  InlineSpan _inline(List<md.Node>? children, TextStyle style) => TextSpan(
    children: [for (final c in children ?? const <md.Node>[]) _span(c, style)],
  );

  InlineSpan _span(md.Node node, TextStyle style) {
    if (node is md.Text) return TextSpan(text: node.text);
    final e = node as md.Element;
    switch (e.tag) {
      case 'strong':
        return TextSpan(
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: [_inline(e.children, style)],
        );
      case 'em':
        return TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: [_inline(e.children, style)],
        );
      case 'del':
        return TextSpan(
          style: const TextStyle(decoration: TextDecoration.lineThrough),
          children: [_inline(e.children, style)],
        );
      case 'code':
        return TextSpan(text: e.textContent, style: _mono(style));
      case 'br':
        return const TextSpan(text: '\n');
      case 'img':
        // Never load remote images: show the alt text (or URL) as a link.
        final src = e.attributes['src'] ?? '';
        final alt = e.attributes['alt'] ?? '';
        return _link(src, alt.isEmpty ? src : alt, null);
      case 'a':
        return _link(e.attributes['href'] ?? '', null, e.children);
      default:
        return _inline(e.children, style);
    }
  }

  InlineSpan _link(String href, String? label, List<md.Node>? children) {
    final uri = parseLink(href);
    final content = label != null
        ? <InlineSpan>[TextSpan(text: label)]
        : [
            for (final c in children ?? const <md.Node>[])
              _span(c, widget.style),
          ];
    if (uri == null) return TextSpan(children: content);
    final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
    _recognizers.add(recognizer);
    return TextSpan(
      style: widget.linkStyle,
      recognizer: recognizer,
      children: content,
    );
  }

  TextStyle _mono(TextStyle style) => style.copyWith(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Menlo', 'Courier', 'Roboto Mono'],
    fontSize: (style.fontSize ?? 14) * 0.92,
    backgroundColor: _tint(style, 0.10),
  );

  Color? _tint(TextStyle style, double alpha) =>
      style.color?.withValues(alpha: alpha);

  /// Block widgets for [nodes]; runs of inline nodes become one paragraph.
  List<Widget> _blocks(List<md.Node> nodes, TextStyle style) {
    final out = <Widget>[];
    var run = <md.Node>[];
    void flush() {
      if (run.isEmpty) return;
      out.add(Text.rich(_inline(run, style), style: style));
      run = [];
    }

    for (final n in nodes) {
      if (n is md.Element && _blockTags.contains(n.tag)) {
        flush();
        out.add(_block(n, style));
      } else {
        run.add(n);
      }
    }
    flush();
    return out;
  }

  Widget _column(List<Widget> items, {double gap = 6}) {
    final spaced = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) spaced.add(SizedBox(height: gap));
      spaced.add(items[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: spaced,
    );
  }

  Widget _block(md.Element e, TextStyle style) {
    final kids = e.children ?? const <md.Node>[];
    switch (e.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        const scale = {
          'h1': 1.3,
          'h2': 1.2,
          'h3': 1.12,
          'h4': 1.06,
          'h5': 1.0,
          'h6': 1.0,
        };
        final s = style.copyWith(
          fontSize: (style.fontSize ?? 14) * scale[e.tag]!,
          fontWeight: FontWeight.w600,
        );
        return Text.rich(_inline(kids, s), style: s);
      case 'ul':
      case 'ol':
        final ordered = e.tag == 'ol';
        final start = int.tryParse(e.attributes['start'] ?? '') ?? 1;
        var i = 0;
        return _column([
          for (final li in kids.whereType<md.Element>())
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ordered ? 24 : 16,
                  child: ExcludeSemantics(
                    excluding: !ordered,
                    child: Text(
                      ordered ? '${start + i++}.' : '•',
                      style: style,
                    ),
                  ),
                ),
                Expanded(
                  child: _column(
                    _blocks(li.children ?? const [], style),
                    gap: 2,
                  ),
                ),
              ],
            ),
        ], gap: 2);
      case 'li':
        return _column(_blocks(kids, style), gap: 2);
      case 'blockquote':
        return Container(
          padding: const EdgeInsetsDirectional.only(start: 10),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                width: 3,
                color: _tint(style, 0.35) ?? const Color(0x00000000),
              ),
            ),
          ),
          child: _column(_blocks(kids, style)),
        );
      case 'pre':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _tint(style, 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              e.textContent.trimRight(),
              style: _mono(style).copyWith(backgroundColor: null),
            ),
          ),
        );
      case 'hr':
        return Container(height: 1, color: _tint(style, 0.25));
      case 'table':
        return _table(e, style);
      default:
        return Text.rich(_inline(kids, style), style: style);
    }
  }

  /// Plain bordered grid, scrollable sideways when wide.
  Widget _table(md.Element e, TextStyle style) {
    final rows = <TableRow>[];
    for (final section in e.children!.whereType<md.Element>()) {
      final header = section.tag == 'thead';
      for (final tr in section.children!.whereType<md.Element>()) {
        final s = header ? style.copyWith(fontWeight: FontWeight.w600) : style;
        rows.add(
          TableRow(
            children: [
              for (final cell in tr.children!.whereType<md.Element>())
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text.rich(_inline(cell.children, s), style: s),
                ),
            ],
          ),
        );
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(
          color: _tint(style, 0.3) ?? const Color(0x00000000),
        ),
        children: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_plain) {
      return LinkifiedText(
        text: widget.text,
        style: widget.style,
        linkStyle: widget.linkStyle,
      );
    }
    _disposeRecognizers();
    return _column(_blocks(_nodes, widget.style));
  }
}
