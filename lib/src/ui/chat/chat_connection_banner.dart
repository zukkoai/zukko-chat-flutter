import 'package:flutter/material.dart';

import '../l10n/zukko_chat_l10n.dart';
import 'chat_connection_monitor.dart';

/// Thin strip under the header while the chat has no connection; shared by
/// all styles. Announced to screen readers when it appears.
class ChatConnectionBanner extends StatelessWidget {
  final ChatConnectionMonitor monitor;
  final ZukkoChatL10n l10n;
  final Color color;
  final double horizontalPadding;

  const ChatConnectionBanner({
    super.key,
    required this.monitor,
    required this.l10n,
    required this.color,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: monitor,
    builder: (context, _) {
      final text = switch (monitor.notice) {
        ChatConnectionNotice.none => null,
        ChatConnectionNotice.offline => l10n.noInternetText,
        ChatConnectionNotice.connecting => l10n.connectingText,
      };
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      return Semantics(
        liveRegion: true,
        child: AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: text == null
              ? const SizedBox(width: double.infinity)
              : ColoredBox(
                  color: color.withValues(alpha: 0.08),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 6,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
