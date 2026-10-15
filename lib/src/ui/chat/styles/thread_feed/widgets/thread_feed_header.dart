import 'package:flutter/material.dart';

import '../../../../l10n/chatwoot_l10n.dart';
import '../../../chatwoot_chat_style.dart';
import '../../../components/chat_avatar.dart';
import '../../../components/chat_icon_button.dart';
import '../thread_feed_tokens.dart';

/// Back/close, square avatar, title with an online dot, menu.
class ThreadFeedHeader extends StatelessWidget {
  final ChatHeaderData data;
  final ZukkoChatL10n l10n;
  final ThreadFeedTokens tokens;

  const ThreadFeedHeader({
    super.key,
    required this.data,
    required this.l10n,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final onBack = data.onBack;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 6, 6),
      child: Row(
        children: [
          if (onBack != null)
            ChatIconButton(
              icon: Icons.chevron_left_rounded,
              iconSize: 28,
              tooltip: l10n.backLabel,
              onPressed: onBack,
              color: tokens.text,
              radius: 10,
            )
          else
            const SizedBox(width: 12),
          ChatAvatar(
            name: data.title,
            size: 40,
            radius: ThreadFeedTokens.radius,
            background: tokens.agentAvatarFill,
            initialStyle: tokens.title.copyWith(color: tokens.agentAvatarText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: tokens.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    if (data.isOnline) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tokens.online,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          data.status,
                          style: tokens.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (data.onMore != null)
            ChatIconButton(
              icon: Icons.more_vert_rounded,
              tooltip: l10n.moreLabel,
              onPressed: data.onMore,
              color: tokens.text,
              radius: 10,
            ),
        ],
      ),
    );
  }
}
