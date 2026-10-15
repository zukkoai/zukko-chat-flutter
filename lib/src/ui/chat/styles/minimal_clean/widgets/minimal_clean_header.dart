import 'package:flutter/material.dart';

import '../../../../l10n/chatwoot_l10n.dart';
import '../../../chatwoot_chat_style.dart';
import '../../../components/chat_icon_button.dart';
import '../minimal_clean_tokens.dart';

/// Centered title and status between the back and the menu button, with a
/// hairline underneath.
class MinimalCleanHeader extends StatelessWidget {
  final ChatHeaderData data;
  final ChatwootL10n l10n;
  final MinimalCleanTokens tokens;

  const MinimalCleanHeader({
    super.key,
    required this.data,
    required this.l10n,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final onBack = data.onBack;
    const slot = SizedBox(width: 48, height: 48);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            if (onBack == null)
              slot
            else
              ChatIconButton(
                icon: Icons.chevron_left_rounded,
                iconSize: 28,
                tooltip: l10n.backLabel,
                onPressed: onBack,
                color: tokens.text,
                radius: 12,
              ),
            Expanded(
              child: Column(
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
            if (data.onMore == null)
              slot
            else
              ChatIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: l10n.moreLabel,
                onPressed: data.onMore,
                color: tokens.text,
                radius: 12,
              ),
          ],
        ),
      ),
    );
  }
}
