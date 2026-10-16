import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter/widgets.dart';

import '../../components/components.dart';
import '../../zukko_chat_style.dart';

/// The flutter_chat_ui builders every style shares: each message type's
/// content comes from `components/message_content.dart`, the style only
/// supplies the [spec] (values and its own bubble / row).
Builders buildMessageBuilders(ChatMessageEnv env, MessageStyleSpec spec) {
  final l10n = env.l10n;

  Widget wrap(
    Message message,
    MessageGroupStatus? group,
    bool isSentByMe,
    MessagePart part,
    Widget child,
  ) {
    final author = env.userById(message.authorId);
    return spec.wrap(
      MessageSlot(
        message: message,
        meta: MessageMeta.of(message, env.timeFormat, group),
        isSentByMe: isSentByMe,
        part: part,
        failedHint: l10n.messageFailedHint,
        authorName: env.authorName(message.authorId, isSentByMe),
        avatarUrl: author?.imageSource,
      ),
      child,
    );
  }

  final row = spec.row;
  return Builders(
    textMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) => wrap(
          message,
          groupStatus,
          isSentByMe,
          MessagePart.text,
          ChatTextMessage(message: message, isSentByMe: isSentByMe, spec: spec),
        ),
    imageMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) => wrap(
          message,
          groupStatus,
          isSentByMe,
          MessagePart.media,
          ChatImageMessage(
            message: message,
            isSentByMe: isSentByMe,
            spec: spec,
            l10n: l10n,
          ),
        ),
    customMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) {
          final images = GalleryMessage.imagesOf(message);
          if (images == null) return const SizedBox.shrink();
          return wrap(
            message,
            groupStatus,
            isSentByMe,
            MessagePart.media,
            ChatGalleryMessage(
              message: message,
              images: images,
              isSentByMe: isSentByMe,
              spec: spec,
              l10n: l10n,
            ),
          );
        },
    fileMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) => wrap(
          message,
          groupStatus,
          isSentByMe,
          MessagePart.file,
          ChatFileMessage(message: message, isSentByMe: isSentByMe, spec: spec),
        ),
    audioMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) => wrap(
          message,
          groupStatus,
          isSentByMe,
          MessagePart.audio,
          ChatAudioMessage(
            message: message,
            spec: spec,
            l10n: l10n,
            playback: env.audio,
          ),
        ),
    chatMessageBuilder:
        (
          context,
          message,
          index,
          animation,
          child, {
          isRemoved,
          required isSentByMe,
          groupStatus,
        }) => ChatMessage(
          message: message,
          index: index,
          animation: animation,
          isRemoved: isRemoved,
          groupStatus: groupStatus,
          // Rows read top-down from the start edge for both authors.
          alignment: row.startAligned ? AlignmentDirectional.centerStart : null,
          scaleAnimationAlignment: row.startAligned
              ? Alignment.centerLeft
              : null,
          sentMessageColumnAlignment: row.startAligned
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          horizontalPadding: env.horizontalPadding + row.extraHorizontal,
          verticalPadding: row.vertical,
          verticalGroupedPadding: row.verticalGrouped,
          child: child,
        ),
    emptyChatListBuilder: (context) => const SizedBox.shrink(),
  );
}
