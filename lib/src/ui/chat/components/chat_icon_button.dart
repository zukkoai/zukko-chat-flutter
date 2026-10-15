import 'package:flutter/material.dart';

/// Icon button with a tooltip and an optional filled shape, used by every
/// style's header and composer (they sit outside the message list, under a
/// flutter Material). The fill is drawn here, so it looks the same with
/// Material 2 and 3 host themes.
class ChatIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final double iconSize;

  /// Filled background; null for a plain icon.
  final Color? fill;

  /// Corner radius of [fill]; null makes it a circle.
  final double? radius;

  /// Width and height; keep it at least 44.
  final double size;

  const ChatIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
    this.iconSize = 22,
    this.fill,
    this.radius,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius;
    final OutlinedBorder shape = r == null
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      color: color,
      disabledColor: color.withValues(alpha: 0.4),
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: shape,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    final f = fill;
    if (f == null) return button;
    return DecoratedBox(
      decoration: ShapeDecoration(color: f, shape: shape),
      child: button,
    );
  }
}
