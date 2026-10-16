import 'package:flutter/material.dart';

import '../../core/zukko_chat_client_exception.dart';
import '../l10n/zukko_chat_l10n.dart';
import 'zukko_chat_controller.dart';

/// The user-facing text of a chat start / session failure.
extension ZukkoChatExceptionText on ZukkoChatException {
  String message(ZukkoChatL10n l10n) => switch (type) {
    ZukkoChatExceptionType.invalidIdentifierHash => l10n.identityRejectedText,
    ZukkoChatExceptionType.sessionExpired => l10n.sessionExpiredText,
    _ => l10n.connectionErrorText,
  };
}

/// Shown while the chat could not be started, with a retry button.
class ChatErrorBanner extends StatelessWidget {
  static const _verticalPadding = 4.0;

  final ZukkoChatController controller;
  final ZukkoChatL10n l10n;
  final Color color;
  final double horizontalPadding;

  const ChatErrorBanner({
    super.key,
    required this.controller,
    required this.l10n,
    required this.color,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final error = controller.error;
      if (error == null) return const SizedBox.shrink();
      final rejected =
          error.type == ZukkoChatExceptionType.invalidIdentifierHash;
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: _verticalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  error.message(l10n),
                  style: TextStyle(color: color),
                ),
              ),
              // the same identity would be rejected again
              if (!rejected)
                TextButton(
                  onPressed: controller.retry,
                  style: TextButton.styleFrom(foregroundColor: color),
                  child: Text(l10n.retryLabel),
                ),
            ],
          ),
        ),
      );
    },
  );
}
