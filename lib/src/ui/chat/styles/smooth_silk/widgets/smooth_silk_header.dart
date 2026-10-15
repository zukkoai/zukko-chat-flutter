import 'package:flutter/material.dart';

import '../../../../l10n/chatwoot_l10n.dart';
import '../../../chatwoot_chat_style.dart';
import '../../../components/chat_avatar.dart';
import '../../../components/chat_icon_button.dart';
import '../smooth_silk_tokens.dart';

/// Borderless header on the chat background: back/close, avatar, title and
/// status, menu.
class SmoothSilkHeader extends StatelessWidget {
  final ChatHeaderData data;
  final ChatwootL10n l10n;
  final SmoothSilkTokens tokens;

  const SmoothSilkHeader({
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
            )
          else
            const SizedBox(width: 12),
          ChatAvatar(
            name: data.title,
            size: 40,
            background: tokens.avatarFill,
            initialStyle: tokens.title.copyWith(color: tokens.avatarText),
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
                Semantics(
                  liveRegion: true,
                  child: Text(
                    data.status,
                    style: tokens.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            ),
        ],
      ),
    );
  }
}
