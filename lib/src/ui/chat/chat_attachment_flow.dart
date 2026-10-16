import 'package:flutter/material.dart';

import '../../core/zukko_chat_upload.dart';

import '../../shared/sdk_log.dart';
import '../l10n/zukko_chat_l10n.dart';
import 'components/components.dart';
import 'zukko_chat_controller.dart';

/// Photo or file sheet, system picker, limit checks, send. A file over a
/// server limit is left out (never cut) and the user is told why. Call only while [context] is
/// mounted; it is not used again after the first await.
Future<void> attachToChat(
  BuildContext context, {
  required ZukkoChatController controller,
  required ZukkoChatL10n l10n,
  required AttachSheetSpec spec,
  required bool Function() isMounted,
  required void Function(String text) notify,
}) async {
  final pick = await pickWithSheet(context, l10n: l10n, spec: spec);
  if (!isMounted()) return;
  final warning = attachmentWarning(l10n, pick);
  if (warning != null) notify(warning);
  if (pick.fitting.isNotEmpty) controller.sendAttachments(pick.fitting);
}

/// The reason files were left out of [pick]; null when none were.
String? attachmentWarning(ZukkoChatL10n l10n, AttachmentPick pick) {
  if (pick.tooLarge > 0) return l10n.fileTooLarge(ZukkoChatUpload.maxSizeMb);
  if (pick.badType > 0) return l10n.fileTypeNotSupportedText;
  if (pick.overCount > 0) {
    return l10n.tooManyFiles(ZukkoChatUpload.maxAttachments);
  }
  return null;
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
