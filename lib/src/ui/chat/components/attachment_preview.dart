import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../l10n/chatwoot_l10n.dart';
import 'image_viewer.dart';

/// Image with a flat placeholder while loading and on error: http(s) urls,
/// or a local file path (the preview of an image being sent; not on web).
class ChatImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final Color placeholderColor;
  final Color iconColor;
  final String? semanticLabel;

  const ChatImage({
    super.key,
    required this.url,
    required this.placeholderColor,
    required this.iconColor,
    this.width,
    this.height,
    this.semanticLabel,
  });

  Widget _placeholder({bool failed = false}) => ColoredBox(
    color: placeholderColor,
    child: SizedBox(
      width: width,
      height: height,
      child: failed
          ? Icon(Icons.broken_image_outlined, size: 24, color: iconColor)
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && _isLocalPath(url)) {
      return Image.file(
        File(url),
        width: width,
        height: height,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        errorBuilder: (_, _, _) => _placeholder(failed: true),
      );
    }
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase();
    // Empty while a picked file uploads (web has no local path).
    if (scheme != 'https' && scheme != 'http') {
      return _placeholder(failed: url.isNotEmpty);
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, _, _) => _placeholder(failed: true),
    );
  }
}

/// The [ImageProvider] [ChatImage] would show for [url]; null when there is
/// nothing to show yet (an upload without a local preview) or the url is not
/// http(s) / a local path.
ImageProvider? chatImageProvider(String url) {
  if (!kIsWeb && _isLocalPath(url)) return FileImage(File(url));
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'https' || scheme == 'http' ? NetworkImage(url) : null;
}

/// A file system path (`/...`, `C:\...`), not a url.
bool _isLocalPath(String source) =>
    source.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source);

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
  final Color overlayColor;
  final TextStyle overlayStyle;
  final String imageLabel;

  /// Id of the message these images belong to (Hero tags) and the strings of
  /// the full-screen viewer a tap opens.
  final String messageId;
  final ChatwootL10n l10n;

  /// False while the message failed to send: a tap then falls through to the
  /// chat's tap-to-resend.
  final bool tapEnabled;

  const ImageGrid({
    super.key,
    required this.urls,
    required this.width,
    required this.placeholderColor,
    required this.iconColor,
    required this.overlayColor,
    required this.overlayStyle,
    required this.imageLabel,
    required this.messageId,
    required this.l10n,
    this.tapEnabled = true,
    this.rowHeight = 96,
    this.gap = 3,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final shown = urls.take(4).toList();
    final hidden = urls.length - shown.length;

    Widget tile(int i, double height) {
      final image = ChatImageTap(
        urls: urls,
        index: i,
        messageId: messageId,
        l10n: l10n,
        enabled: tapEnabled,
        child: ChatImage(
          url: shown[i],
          height: height,
          width: double.infinity,
          placeholderColor: placeholderColor,
          iconColor: iconColor,
          semanticLabel: '$imageLabel ${i + 1}',
        ),
      );
      if (hidden <= 0 || i != shown.length - 1) return image;
      return Stack(
        fit: StackFit.passthrough,
        children: [
          image,
          Positioned.fill(
            child: ColoredBox(
              color: overlayColor,
              child: Center(child: Text('+$hidden', style: overlayStyle)),
            ),
          ),
        ],
      );
    }

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

/// File attachment: icon tile, name and size.
class FileTile extends StatelessWidget {
  final String name;
  final int? size;
  final Color iconFill;
  final Color iconColor;
  final TextStyle nameStyle;
  final TextStyle sizeStyle;
  final double iconRadius;

  const FileTile({
    super.key,
    required this.name,
    required this.iconFill,
    required this.iconColor,
    required this.nameStyle,
    required this.sizeStyle,
    this.size,
    this.iconRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = size;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconFill,
            borderRadius: BorderRadius.circular(iconRadius),
          ),
          child: Icon(
            Icons.insert_drive_file_outlined,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: nameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (bytes != null) Text(formatBytes(bytes), style: sizeStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// `512 B`, `1.4 KB`, `12 MB`.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
