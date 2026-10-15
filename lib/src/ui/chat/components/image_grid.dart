import 'package:flutter/widgets.dart';

import '../../l10n/zukko_chat_l10n.dart';
import 'chat_image.dart';
import 'chat_image_tap.dart';

/// One to four images in a tight grid; more show `+N` on the last tile.
/// 2: side by side, 3: one tall + two stacked, 4+: 2 x 2.
class ImageGrid extends StatelessWidget {
  final List<String> urls;
  final double width;

  /// Height of one row (a single image is 1.5 rows tall).
  final double rowHeight;
  final double gap;
  final double radius;
  final Color placeholderColor;
  final Color iconColor;

  /// Dim layer and text of the `+N` tile.
  final Color overlayColor;
  final TextStyle overlayStyle;

  static const _defaultOverlayStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  final String imageLabel;

  /// Id of the message these images belong to (Hero tags) and the strings of
  /// the full-screen viewer a tap opens.
  final String messageId;
  final ZukkoChatL10n l10n;

  /// False while the message failed to send: a tap then falls through to the
  /// chat's tap-to-resend.
  final bool tapEnabled;

  const ImageGrid({
    super.key,
    required this.urls,
    required this.width,
    required this.placeholderColor,
    required this.iconColor,
    required this.imageLabel,
    required this.messageId,
    required this.l10n,
    this.tapEnabled = true,
    this.overlayColor = const Color(0x66000000),
    this.overlayStyle = _defaultOverlayStyle,
    this.rowHeight = 96,
    this.gap = 3,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final shown = urls.take(4).toList();
    final hidden = urls.length - shown.length;

    Widget tile(int i, double height) => _ImageGridTile(
      grid: this,
      shown: shown,
      hidden: hidden,
      index: i,
      height: height,
    );

    final gapBox = SizedBox(width: gap, height: gap);
    final tall = rowHeight * 2 + gap;
    final Widget grid = switch (shown.length) {
      0 => const SizedBox.shrink(),
      1 => tile(0, rowHeight * 1.5),
      2 => Row(
        children: [
          Expanded(child: tile(0, tall * 0.7)),
          gapBox,
          Expanded(child: tile(1, tall * 0.7)),
        ],
      ),
      3 => Row(
        children: [
          Expanded(child: tile(0, tall)),
          gapBox,
          Expanded(
            child: Column(
              children: [tile(1, rowHeight), gapBox, tile(2, rowHeight)],
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          Row(
            children: [
              Expanded(child: tile(0, rowHeight)),
              gapBox,
              Expanded(child: tile(1, rowHeight)),
            ],
          ),
          gapBox,
          Row(
            children: [
              Expanded(child: tile(2, rowHeight)),
              gapBox,
              Expanded(child: tile(3, rowHeight)),
            ],
          ),
        ],
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, child: grid),
    );
  }
}

class _ImageGridTile extends StatelessWidget {
  final ImageGrid grid;
  final List<String> shown;
  final int hidden;
  final int index;
  final double height;

  const _ImageGridTile({
    required this.grid,
    required this.shown,
    required this.hidden,
    required this.index,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final image = ChatImageTap(
      urls: grid.urls,
      index: index,
      messageId: grid.messageId,
      l10n: grid.l10n,
      enabled: grid.tapEnabled,
      child: ChatImage(
        url: shown[index],
        height: height,
        width: double.infinity,
        placeholderColor: grid.placeholderColor,
        iconColor: grid.iconColor,
        semanticLabel: '${grid.imageLabel} ${index + 1}',
      ),
    );
    if (hidden <= 0 || index != shown.length - 1) return image;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        image,
        Positioned.fill(
          child: ColoredBox(
            color: grid.overlayColor,
            child: Center(child: Text('+$hidden', style: grid.overlayStyle)),
          ),
        ),
      ],
    );
  }
}
