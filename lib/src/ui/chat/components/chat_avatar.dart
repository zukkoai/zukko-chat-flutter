import 'package:flutter/widgets.dart';

import 'attachment_preview.dart';

/// Avatar: the image when there is an https url, else the initial.
class ChatAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;

  /// Corner radius; null makes it a circle.
  final double? radius;
  final Color background;
  final TextStyle initialStyle;

  const ChatAvatar({
    super.key,
    required this.name,
    required this.size,
    required this.background,
    required this.initialStyle,
    this.imageUrl,
    this.radius,
  });

  String get _initial {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final shape = BorderRadius.circular(radius ?? size / 2);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: shape,
        child: SizedBox.square(
          dimension: size,
          child: url != null && url.startsWith('https://')
              ? ChatImage(
                  url: url,
                  placeholderColor: background,
                  iconColor: initialStyle.color ?? background,
                )
              : ColoredBox(
                  color: background,
                  child: Center(child: Text(_initial, style: initialStyle)),
                ),
        ),
      ),
    );
  }
}
