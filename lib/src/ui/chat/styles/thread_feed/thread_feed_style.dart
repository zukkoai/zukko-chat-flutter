import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

import '../../../l10n/chatwoot_l10n.dart';
import '../../../theme/chatwoot_chat_theme.dart';
import '../../chatwoot_chat_style.dart';
import '../../components/attachment_preview.dart';
import '../../components/image_viewer.dart';
import '../../components/audio_player.dart';
import '../../components/gallery_message.dart';
import '../../components/link_launcher.dart';
import '../../components/link_preview.dart';
import '../../components/linkified_text.dart';
import '../../components/message_meta.dart';
import '../../components/powered_by.dart';
import '../../components/typing_indicator.dart';
import 'thread_feed_tokens.dart';
import 'widgets/thread_feed_composer.dart';
import 'widgets/thread_feed_header.dart';
import 'widgets/thread_feed_row.dart';

/// Entry of the Thread Feed style.
class ThreadFeedStyle extends ChatStyle {
  ThreadFeedStyle(ChatwootChatTheme theme)
    : _theme = theme,
      tokens = ThreadFeedTokens.from(theme);

  final ChatwootChatTheme _theme;
  final ThreadFeedTokens tokens;

  static const _mediaWidth = 260.0;

  @override
  Brightness get brightness => tokens.brightness;

  @override
  Color get backgroundColor => tokens.background;

  @override
  Color get foregroundColor => tokens.text;

  @override
  Color get accentColor => tokens.accent;

  @override
  ChatTheme get chatTheme => ChatTheme(
    colors: ChatColors(
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      surface: tokens.background,
      onSurface: tokens.text,
      surfaceContainer: tokens.fieldFill,
      surfaceContainerLow: tokens.fieldFill,
      surfaceContainerHigh: tokens.cardFill,
    ),
    typography: ChatTypography.standard().copyWith(
      bodyMedium: tokens.body,
      labelSmall: tokens.caption,
    ),
    shape: BorderRadius.circular(ThreadFeedTokens.radius),
  );

  @override
  Widget buildHeader(
    BuildContext context,
    ChatHeaderData data,
    ChatwootL10n l10n,
  ) => ThreadFeedHeader(data: data, l10n: l10n, tokens: tokens);

  @override
  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ChatwootL10n l10n,
  ) => ThreadFeedComposer(
    data: data,
    l10n: l10n,
    tokens: tokens,
    horizontalPadding: _theme.horizontalPadding,
  );

  @override
  Widget buildTypingIndicator(BuildContext context, ChatwootL10n l10n) =>
      Padding(
        padding: EdgeInsetsDirectional.only(
          start:
              _theme.horizontalPadding +
              ThreadFeedTokens.avatarSize +
              ThreadFeedTokens.avatarGap,
          top: 6,
          bottom: 4,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TypingIndicator(
            color: tokens.typingDot,
            semanticLabel: l10n.typingText,
          ),
        ),
      );

  @override
  Widget buildFooter(BuildContext context, ChatwootL10n l10n) => PoweredBy(
    prefix: l10n.poweredByText,
    style: tokens.caption.copyWith(fontSize: 11),
    linkColor: tokens.link,
  );

  @override
  Builders messageBuilders(ChatMessageEnv env) {
    final l10n = env.l10n;

    ThreadFeedRow row(
      Message message,
      MessageGroupStatus? group, {
      required bool isSentByMe,
      required Widget child,
    }) {
      final author = env.userById(message.authorId);
      return ThreadFeedRow(
        tokens: tokens,
        isSentByMe: isSentByMe,
        authorName: isSentByMe
            ? l10n.youLabel
            : (author?.name?.trim().isNotEmpty ?? false)
            ? author!.name!
            : l10n.headerTitle,
        avatarUrl: author?.imageSource,
        meta: MessageMeta.of(message, env.timeFormat, group),
        failedHint: l10n.messageFailedHint,
        child: child,
      );
    }

    Widget withCaption(Widget media, String? caption) =>
        caption == null || caption.trim().isEmpty
        ? media
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [media, const SizedBox(height: 8), _text(caption)],
          );

    return Builders(
      textMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final links = findLinks(message.text);
            return row(
              message,
              groupStatus,
              isSentByMe: isSentByMe,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _text(message.text),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    LinkPreviewCard(
                      uri: links.first.uri,
                      data: message.linkPreviewData,
                      direction: Axis.horizontal,
                      look: _linkLook,
                    ),
                  ],
                ],
              ),
            );
          },
      imageMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) => row(
            message,
            groupStatus,
            isSentByMe: isSentByMe,
            child: withCaption(
              ClipRRect(
                borderRadius: BorderRadius.circular(ThreadFeedTokens.radius),
                child: ChatImageTap(
                  urls: [message.source],
                  index: 0,
                  messageId: message.id,
                  l10n: l10n,
                  enabled: message.status != MessageStatus.error,
                  child: ChatImage(
                    url: message.source,
                    width: _mediaWidth,
                    height: 172,
                    placeholderColor: tokens.media,
                    iconColor: tokens.mediaIcon,
                    semanticLabel: l10n.imageLabel,
                  ),
                ),
              ),
              message.text,
            ),
          ),
      customMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final images = GalleryMessage.imagesOf(message);
            if (images == null) return const SizedBox.shrink();
            return row(
              message,
              groupStatus,
              isSentByMe: isSentByMe,
              child: withCaption(
                ImageGrid(
                  urls: images,
                  width: _mediaWidth,
                  radius: ThreadFeedTokens.radius,
                  gap: 4,
                  rowHeight: 84,
                  placeholderColor: tokens.media,
                  iconColor: tokens.mediaIcon,
                  overlayColor: const Color(0x73141816),
                  overlayStyle: tokens.title.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                  imageLabel: l10n.imageLabel,
                  messageId: message.id,
                  l10n: l10n,
                  tapEnabled: message.status != MessageStatus.error,
                ),
                GalleryMessage.captionOf(message),
              ),
            );
          },
      fileMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) => row(
            message,
            groupStatus,
            isSentByMe: isSentByMe,
            child: _card(
              FileTile(
                name: message.name,
                size: message.size,
                iconFill: tokens.fieldFill,
                iconColor: tokens.accent,
                nameStyle: tokens.bodyStrong,
                sizeStyle: tokens.caption,
                iconRadius: 8,
              ),
            ),
          ),
      audioMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) => row(
            message,
            groupStatus,
            isSentByMe: isSentByMe,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
              decoration: BoxDecoration(
                color: tokens.fieldFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AudioPlayerBar(
                playback: env.audio,
                source: message.source,
                playLabel: l10n.playLabel,
                pauseLabel: l10n.pauseLabel,
                duration: message.duration,
                waveform: message.waveform ?? placeholderWaveform(message.id),
                semanticLabel: l10n.voiceMessageLabel,
                durationStyle: tokens.caption,
                buttonSize: 34,
                buttonRadius: 8,
                colors: AudioPlayerColors(
                  buttonFill: tokens.accent,
                  buttonIcon: tokens.onAccent,
                  waveActive: tokens.accent,
                  waveInactive: tokens.waveInactive,
                ),
              ),
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
            alignment: AlignmentDirectional.centerStart,
            scaleAnimationAlignment: Alignment.centerLeft,
            sentMessageColumnAlignment: CrossAxisAlignment.start,
            horizontalPadding: env.horizontalPadding,
            verticalPadding: 14,
            verticalGroupedPadding: 6,
            child: child,
          ),
      emptyChatListBuilder: (context) => const SizedBox.shrink(),
    );
  }

  Widget _text(String text) => LinkifiedText(
    text: text,
    style: tokens.body,
    linkStyle: tokens.body.copyWith(
      color: tokens.link,
      decoration: TextDecoration.underline,
      decorationColor: tokens.link,
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: tokens.cardFill,
      borderRadius: BorderRadius.circular(ThreadFeedTokens.radius),
      border: Border.all(color: tokens.cardBorder),
    ),
    child: child,
  );

  LinkPreviewLook get _linkLook => LinkPreviewLook(
    fill: tokens.cardFill,
    border: tokens.cardBorder,
    thumbnailFill: tokens.media,
    iconColor: tokens.mediaIcon,
    domainStyle: tokens.caption,
    titleStyle: tokens.bodyStrong,
    descriptionStyle: tokens.caption.copyWith(color: tokens.text),
    radius: ThreadFeedTokens.radius,
  );
}
