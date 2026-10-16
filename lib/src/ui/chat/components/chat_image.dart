import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../shared/url_policy.dart';

/// Image with a flat placeholder while loading and on error: http(s) urls,
/// or a local file path (the preview of an image being sent; not on web).
///
/// It is decoded at the size it is drawn at (not full resolution), so a
/// large photo in a small bubble or avatar stays cheap in the image cache.
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

  @override
  Widget build(BuildContext context) {
    final local = !kIsWeb && isLocalImagePath(url);
    // Empty while a picked file uploads (web has no local path).
    if (!local && !isHttpUrl(url)) {
      return _ImagePlaceholder(
        color: placeholderColor,
        iconColor: iconColor,
        width: width,
        height: height,
        failed: url.isNotEmpty,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = _finiteOrNull(width) ?? _finiteOrNull(constraints.maxWidth);
        final h = _finiteOrNull(height);
        final bound = math.max(w ?? 0, h ?? 0);
        // Decode the longer drawn side: `cover` never needs more than that.
        final cache = bound > 0 ? (bound * dpr).ceil() : null;
        final cacheWidth = w != null ? cache : null;
        final cacheHeight = w == null ? cache : null;
        final failed = _ImagePlaceholder(
          color: placeholderColor,
          iconColor: iconColor,
          width: width,
          height: height,
          failed: true,
        );
        if (local) {
          return Image.file(
            File(url),
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            fit: BoxFit.cover,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
            errorBuilder: (_, _, _) => failed,
          );
        }
        return Image.network(
          url,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : _ImagePlaceholder(
                  color: placeholderColor,
                  iconColor: iconColor,
                  width: width,
                  height: height,
                ),
          errorBuilder: (_, _, _) => failed,
        );
      },
    );
  }

  static double? _finiteOrNull(double? v) =>
      v != null && v.isFinite && v > 0 ? v : null;
}

class _ImagePlaceholder extends StatelessWidget {
  static const _iconSize = 24.0;

  final Color color;
  final Color iconColor;
  final double? width;
  final double? height;
  final bool failed;

  const _ImagePlaceholder({
    required this.color,
    required this.iconColor,
    required this.width,
    required this.height,
    this.failed = false,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: SizedBox(
      width: width,
      height: height,
      child: failed
          ? Icon(Icons.broken_image_outlined, size: _iconSize, color: iconColor)
          : null,
    ),
  );
}

/// The [ImageProvider] [ChatImage] would show for [url]; null when there is
/// nothing to show yet (an upload without a local preview) or the url is not
/// http(s) / a local path.
ImageProvider? chatImageProvider(String url) {
  if (!kIsWeb && isLocalImagePath(url)) return FileImage(File(url));
  return isHttpUrl(url) ? NetworkImage(url) : null;
}

/// A file system path (`/...`, `C:\...`), not a url.
bool isLocalImagePath(String source) =>
    source.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source);
