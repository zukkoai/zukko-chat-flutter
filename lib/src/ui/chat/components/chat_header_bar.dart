import 'package:flutter/material.dart';

import '../../l10n/zukko_chat_l10n.dart';
import 'chat_avatar.dart';
import 'chat_icon_button.dart';

/// Look of the agent avatar in a header.
@immutable
class HeaderAvatarLook {
  final Color fill;
  final TextStyle initialStyle;
  final double size;

  /// Corner radius; null makes it a circle.
  final double? radius;

  const HeaderAvatarLook({
    required this.fill,
    required this.initialStyle,
    this.size = 40,
    this.radius,
  });
}

/// Values of a [ChatHeaderBar] that differ between the styles.
@immutable
class HeaderBarLook {
  final TextStyle titleStyle;
  final TextStyle statusStyle;
  final Color iconColor;

  /// Corner radius of the back / menu buttons; null makes them round.
  final double? buttonRadius;
  final IconData moreIcon;

  /// Null: no avatar.
  final HeaderAvatarLook? avatar;

  /// Title and status centered between the buttons (else start-aligned).
  final bool centered;

  /// Hairline under the bar.
  final Color? divider;

  /// A dot before the status while online.
  final Color? onlineDot;
  final EdgeInsetsGeometry padding;

  const HeaderBarLook({
    required this.titleStyle,
    required this.statusStyle,
    required this.iconColor,
    required this.moreIcon,
    required this.padding,
    this.buttonRadius,
    this.avatar,
    this.centered = false,
    this.divider,
    this.onlineDot,
  });
}

/// Header shared by every style: back / close, optional avatar, title with
/// a live status, menu. The style only picks the [look].
class ChatHeaderBar extends StatelessWidget {
  final String title;
  final String status;
  final bool isOnline;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final ZukkoChatL10n l10n;
  final HeaderBarLook look;

  /// Width of the empty slot that keeps a centered title centered.
  static const _slot = 48.0;

  const ChatHeaderBar({
    super.key,
    required this.title,
    required this.status,
    required this.isOnline,
    required this.onBack,
    required this.onMore,
    required this.l10n,
    required this.look,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = look.avatar;
    final divider = look.divider;
    final bar = Padding(
      padding: look.padding,
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.chevron_left_rounded,
            iconSize: 28,
            tooltip: l10n.backLabel,
            onPressed: onBack,
            emptyWidth: look.centered ? _slot : 12,
            look: look,
          ),
          if (avatar != null) ...[
            ChatAvatar(
              name: title,
              size: avatar.size,
              radius: avatar.radius,
              background: avatar.fill,
              initialStyle: avatar.initialStyle,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: HeaderTitleBlock(
              title: title,
              status: status,
              showDot: isOnline,
              look: look,
            ),
          ),
          _HeaderButton(
            icon: look.moreIcon,
            tooltip: l10n.moreLabel,
            onPressed: onMore,
            emptyWidth: look.centered ? _slot : 0,
            look: look,
          ),
        ],
      ),
    );
    if (divider == null) return bar;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: bar,
    );
  }
}

/// Title (a heading for screen readers) over a live status line.
class HeaderTitleBlock extends StatelessWidget {
  final String title;
  final String status;
  final bool showDot;
  final HeaderBarLook look;

  const HeaderTitleBlock({
    super.key,
    required this.title,
    required this.status,
    required this.showDot,
    required this.look,
  });

  static const _dotSize = 7.0;

  @override
  Widget build(BuildContext context) {
    final dot = look.onlineDot;
    final statusText = Semantics(
      liveRegion: true,
      child: Text(
        status,
        style: look.statusStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Column(
      crossAxisAlignment: look.centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: look.titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (dot != null && showDot)
          Row(
            children: [
              Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(child: statusText),
            ],
          )
        else
          statusText,
      ],
    );
  }
}

/// Back or menu button; an empty slot ([emptyWidth]) when [onPressed] is
/// null, so the title keeps its place.
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback? onPressed;
  final double emptyWidth;
  final HeaderBarLook look;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.emptyWidth,
    required this.look,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) {
      return SizedBox(
        width: emptyWidth,
        height: look.centered ? ChatHeaderBar._slot : null,
      );
    }
    return ChatIconButton(
      icon: icon,
      iconSize: iconSize,
      tooltip: tooltip,
      onPressed: onPressed,
      color: look.iconColor,
      radius: look.buttonRadius,
    );
  }
}
