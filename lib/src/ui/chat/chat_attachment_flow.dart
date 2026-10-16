import 'package:flutter/material.dart';

import '../../core/zukko_chat_upload.dart';

import '../../shared/sdk_log.dart';
import '../l10n/zukko_chat_l10n.dart';
import 'components/components.dart';
import 'zukko_chat_controller.dart';

/// Photo or file sheet, system picker, size check, send. A file over the
/// limit is left out and the user is told. Call only while [context] is
/// mounted; it is not used again after the first await.
Future<void> attachToChat(
  BuildContext context, {
  required ZukkoChatController controller,
  required ZukkoChatL10n l10n,
  required Color background,
  required Color foreground,
  required bool Function() isMounted,
  required void Function(String text) notify,
}) async {
  final pick = await pickWithSheet(
    context,
    l10n: l10n,
    background: background,
    foreground: foreground,
  );
  if (!isMounted()) return;
  if (pick.tooLarge > 0) {
    notify(l10n.fileTooLarge(ZukkoChatUpload.maxSizeMb));
  }
  controller.sendAttachments(pick.fitting);
}

/// The text for a microphone problem.
String voiceIssueText(ZukkoChatL10n l10n, VoiceRecorderIssue issue) =>
    switch (issue) {
      VoiceRecorderIssue.permissionDenied => l10n.microphoneDeniedText,
      VoiceRecorderIssue.failed => l10n.voiceRecordFailedText,
    };

/// A short message at the bottom of the screen. Without a
/// `ScaffoldMessenger` above [context] there is nowhere to show it: it is
/// only logged.
void showChatNotice(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    sdkLog('notice dropped, no ScaffoldMessenger: $text');
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
