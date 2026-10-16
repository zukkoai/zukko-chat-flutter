import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/zukko_chat_l10n.dart';

/// What the attachment button picks.
enum AttachmentSource { image, file }

/// How the two options (photo, file) are laid out.
enum AttachOptionLayout {
  /// Side by side, icon disc above the text (Smooth Silk).
  cards,

  /// Side by side, icon beside the text, with a border (Thread Feed).
  tiles,

  /// One per line inside a floating group (Minimal Clean).
  list,
}

/// Which of the subtitle variants a style shows under "Photo" / "File".
enum AttachHints { standard, descriptive, compact }

/// Everything a style decides about the attachment sheet; the shared
/// [AttachSheet] draws it. Values come from the style's tokens.
@immutable
class AttachSheetSpec {
  final AttachOptionLayout layout;
  final AttachHints hints;

  /// Title is "Attach · up to N MB each" and there is no separate note.
  final bool titleWithLimit;

  /// Darkens the chat behind the sheet.
  final Color scrim;

  /// Sheet (or, for [AttachOptionLayout.list], the option group) fill.
  final Color fill;
  final BorderRadius radius;

  /// Space around the content inside the sheet.
  final EdgeInsets padding;

  /// Distance of a floating sheet from the screen edges (list layout).
  final EdgeInsets margin;

  /// Gap between the parts of the sheet.
  final double gap;

  /// Handle color; null shows none.
  final Color? handle;

  final TextStyle titleStyle;
  final EdgeInsets titlePadding;

  /// Close button in the title row (Thread Feed); null shows none.
  final AttachCloseLook? close;

  final TextStyle labelStyle;
  final TextStyle hintStyle;
  final Color optionFill;
  final Color? optionBorder;
  final double optionRadius;
  final EdgeInsets optionPadding;
  final double optionGap;

  /// Row separators and minimum row height of the list layout.
  final Color divider;
  final double rowHeight;

  final Color discFill;
  final double discSize;
  final double discRadius;
  final Color iconColor;
  final double iconSize;
  final IconData imageIcon;
  final IconData fileIcon;

  /// Limit note under the options; null shows none.
  final TextStyle? noteStyle;
  final TextAlign noteAlign;

  /// Cancel button; null shows none.
  final AttachCancelLook? cancel;

  const AttachSheetSpec({
    required this.layout,
    required this.hints,
    required this.scrim,
    required this.fill,
    required this.radius,
    required this.padding,
    required this.gap,
    required this.titleStyle,
    required this.labelStyle,
    required this.hintStyle,
    required this.optionFill,
    required this.optionRadius,
    required this.optionPadding,
    required this.optionGap,
    required this.discFill,
    required this.discSize,
    required this.discRadius,
    required this.iconColor,
    required this.iconSize,
    required this.imageIcon,
    required this.fileIcon,
    this.titleWithLimit = false,
    this.margin = EdgeInsets.zero,
    this.handle,
    this.titlePadding = EdgeInsets.zero,
    this.close,
    this.optionBorder,
    this.divider = Colors.transparent,
    this.rowHeight = 0,
    this.noteStyle,
    this.noteAlign = TextAlign.center,
    this.cancel,
  });
}

/// The round-corner close button of the title row.
@immutable
class AttachCloseLook {
  final Color fill;
  final Color icon;
  final double size;
  final double radius;
  final double iconSize;

  const AttachCloseLook({
    required this.fill,
    required this.icon,
    required this.size,
    required this.radius,
    required this.iconSize,
  });
}

/// The full-width cancel button under the options.
@immutable
class AttachCancelLook {
  final Color fill;
  final TextStyle style;
  final double height;
  final double radius;

  const AttachCancelLook({
    required this.fill,
    required this.style,
    required this.height,
    required this.radius,
  });
}

/// Bottom sheet: photo or file. Null when dismissed.
Future<AttachmentSource?> showAttachmentSourceSheet(
  BuildContext context, {
  required ZukkoChatL10n l10n,
  required AttachSheetSpec spec,
  required int maxMb,
}) => showModalBottomSheet<AttachmentSource>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: spec.scrim,
  elevation: 0,
  isScrollControlled: true,
  clipBehavior: Clip.none,
  // The design's "rise": 500 ms, ease-out.
  sheetAnimationStyle: const AnimationStyle(
    duration: Duration(milliseconds: 500),
    reverseDuration: Duration(milliseconds: 250),
    curve: Cubic(0.2, 0.8, 0.2, 1),
    reverseCurve: Curves.easeIn,
  ),
  builder: (context) => AttachSheet(spec: spec, l10n: l10n, maxMb: maxMb),
);

/// The sheet's content: pops with the chosen [AttachmentSource], or with
/// null on cancel / close.
class AttachSheet extends StatelessWidget {
  final AttachSheetSpec spec;
  final ZukkoChatL10n l10n;
  final int maxMb;

  const AttachSheet({
    super.key,
    required this.spec,
    required this.l10n,
    required this.maxMb,
  });

  String get _title => spec.titleWithLimit
      ? l10n.attachSheetTitleWithLimit(maxMb)
      : l10n.attachSheetTitle;

  String get _imageHint => switch (spec.hints) {
    AttachHints.standard => l10n.attachImageHint,
    AttachHints.descriptive => l10n.attachImageHintLong,
    AttachHints.compact => l10n.attachImageHintShort,
  };

  String get _fileHint => spec.hints == AttachHints.compact
      ? l10n.attachFileHintShort
      : l10n.attachFileHint;

  void _pop(BuildContext context, [AttachmentSource? source]) =>
      Navigator.pop(context, source);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = math.max(spec.padding.bottom, media.viewPadding.bottom);
    final image = _Option(
      spec: spec,
      icon: spec.imageIcon,
      label: l10n.attachImageLabel,
      hint: _imageHint,
      onTap: () => _pop(context, AttachmentSource.image),
    );
    final file = _Option(
      spec: spec,
      icon: spec.fileIcon,
      label: l10n.attachFileLabel,
      hint: _fileHint,
      onTap: () => _pop(context, AttachmentSource.file),
    );
    final body = spec.layout == AttachOptionLayout.list
        ? _floating(context, image, file)
        : _docked(context, image, file, bottom);
    // The modal route bottom-aligns the sheet, so it must hug its content
    // (a full-height box would swallow taps meant for the scrim).
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height - media.padding.top,
      ),
      child: SingleChildScrollView(reverse: true, child: body),
    );
  }

  Widget _docked(BuildContext context, Widget image, Widget file, double b) {
    final p = spec.padding;
    return DecoratedBox(
      decoration: BoxDecoration(color: spec.fill, borderRadius: spec.radius),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(p.left, p.top, p.right, b),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spec.gap,
            children: [
              if (spec.handle != null) _handle(),
              _titleRow(context),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    Expanded(child: image),
                    Expanded(child: file),
                  ],
                ),
              ),
              ..._note(),
              ..._cancel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floating(BuildContext context, Widget image, Widget file) {
    final m = spec.margin;
    final bottom = math.max(m.bottom, MediaQuery.viewPaddingOf(context).bottom);
    return Padding(
      padding: EdgeInsets.fromLTRB(m.left, 0, m.right, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spec.gap,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: spec.fill,
              borderRadius: spec.radius,
            ),
            child: ClipRRect(
              borderRadius: spec.radius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: spec.titlePadding,
                    child: Text(_title, style: spec.titleStyle),
                  ),
                  _divider(),
                  image,
                  _divider(),
                  file,
                ],
              ),
            ),
          ),
          ..._cancel(context),
        ],
      ),
    );
  }

  Widget _divider() => ColoredBox(
    color: spec.divider,
    child: const SizedBox(height: 1, width: double.infinity),
  );

  Widget _handle() => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: spec.handle,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const SizedBox(width: 36, height: 5),
    ),
  );

  Widget _titleRow(BuildContext context) {
    if (spec.layout == AttachOptionLayout.list) return const SizedBox.shrink();
    final title = Padding(
      padding: spec.titlePadding,
      child: Semantics(
        header: true,
        child: Text(_title, style: spec.titleStyle),
      ),
    );
    final close = spec.close;
    if (close == null) return title;
    return Row(
      children: [
        Expanded(child: title),
        // 48 dp touch target around the 36 dp visual button.
        Semantics(
          button: true,
          label: l10n.closeLabel,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pop(context),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: close.fill,
                    borderRadius: BorderRadius.circular(close.radius),
                  ),
                  child: SizedBox.square(
                    dimension: close.size,
                    child: Icon(
                      Icons.close_rounded,
                      size: close.iconSize,
                      color: close.icon,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _note() {
    final style = spec.noteStyle;
    if (style == null || spec.titleWithLimit) return const [];
    return [
      Text(
        l10n.attachLimitNote(maxMb),
        style: style,
        textAlign: spec.noteAlign,
      ),
    ];
  }

  List<Widget> _cancel(BuildContext context) {
    final c = spec.cancel;
    if (c == null) return const [];
    return [
      Material(
        color: c.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(c.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pop(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.height),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  l10n.cancelLabel,
                  style: c.style,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _Option extends StatelessWidget {
  final AttachSheetSpec spec;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _Option({
    required this.spec,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spec.layout == AttachOptionLayout.cards ? 2 : 0,
      children: [
        Text(label, style: spec.labelStyle),
        Text(hint, style: spec.hintStyle),
      ],
    );
    final glyph = spec.layout == AttachOptionLayout.list
        ? Icon(icon, size: spec.iconSize, color: spec.iconColor)
        : DecoratedBox(
            decoration: BoxDecoration(
              color: spec.discFill,
              borderRadius: BorderRadius.circular(spec.discRadius),
            ),
            child: SizedBox.square(
              dimension: spec.discSize,
              child: Icon(icon, size: spec.iconSize, color: spec.iconColor),
            ),
          );
    final content = switch (spec.layout) {
      AttachOptionLayout.cards => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spec.optionGap,
        children: [glyph, texts],
      ),
      _ => Row(
        spacing: spec.optionGap,
        children: [
          glyph,
          Expanded(child: texts),
        ],
      ),
    };
    final border = spec.optionBorder;
    return Semantics(
      button: true,
      label: '$label, $hint',
      excludeSemantics: true,
      child: Material(
        color: spec.optionFill,
        shape: spec.layout == AttachOptionLayout.list
            ? const RoundedRectangleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(spec.optionRadius),
                side: border == null
                    ? BorderSide.none
                    : BorderSide(color: border),
              ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(48, spec.rowHeight),
            ),
            child: Padding(
              padding: spec.optionPadding,
              child: Align(
                alignment: spec.layout == AttachOptionLayout.cards
                    ? Alignment.topLeft
                    : Alignment.centerLeft,
                widthFactor: 1,
                heightFactor: 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
