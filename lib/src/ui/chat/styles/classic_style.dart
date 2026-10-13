import 'package:flutter/material.dart' hide OutlineInputBorder;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' show OutlineInputBorder;

import '../chatwoot_chat_style.dart';

/// Bubbles with avatars and names on the left, rounded filled composer.
Builders classicBuilders(ChatwootStyleArgs a) {
  final theme = a.theme;
  return Builders(
    textMessageBuilder:
        (context, message, index, {required isSentByMe, groupStatus}) =>
            SimpleTextMessage(
              message: message,
              index: index,
              sentBackgroundColor: theme.primaryColor,
              receivedBackgroundColor: theme.secondaryColor,
              sentTextStyle: theme.sentMessageBodyTextStyle,
              receivedTextStyle: theme.receivedMessageBodyTextStyle,
              timeStyle: isSentByMe
                  ? theme.sentMessageCaptionTextStyle
                  : theme.receivedMessageCaptionTextStyle,
              borderRadius: BorderRadius.circular(theme.messageBorderRadius),
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
        }) {
          final failed = message.status == MessageStatus.error;
          return ChatMessage(
            message: message,
            index: index,
            animation: animation,
            isRemoved: isRemoved,
            groupStatus: groupStatus,
            leadingWidget: a.showUserAvatars && !isSentByMe
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Avatar(
                      userId: message.authorId,
                      backgroundColor: theme.avatarColorFor(message.authorId),
                    ),
                  )
                : null,
            topWidget: a.showUserNames && !isSentByMe
                ? Padding(
                    // avatar (32) + gap (8)
                    padding: EdgeInsetsDirectional.only(
                      start: a.showUserAvatars ? 40 : 0,
                      bottom: 2,
                    ),
                    child: Username(
                      userId: message.authorId,
                      style: theme.userNameTextStyle,
                    ),
                  )
                : null,
            child: failed
                ? Semantics(hint: a.l10n.messageFailedHint, child: child)
                : child,
          );
        },
    chatAnimatedListBuilder: (context, itemBuilder) => ChatAnimatedList(
      itemBuilder: itemBuilder,
      onEndReached: a.onEndReached,
      paginationThreshold: a.paginationThreshold ?? 0.01,
    ),
    composerBuilder: (context) => Composer(
      hintText: a.l10n.inputPlaceholder,
      backgroundColor: theme.backgroundColor,
      inputFillColor: theme.inputBackgroundColor,
      textColor: theme.inputTextColor,
      sendIconColor: theme.primaryColor,
      // null would remove the icon (the Composer default is only used when omitted)
      sendIcon: theme.sendButtonIcon ?? const Icon(Icons.send),
      inputBorder: OutlineInputBorder(
        borderRadius: theme.inputBorderRadius,
        borderSide: BorderSide.none,
      ),
    ),
  );
}
