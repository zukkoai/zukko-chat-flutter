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
import 'minimal_clean_tokens.dart';
import 'widgets/minimal_clean_composer.dart';
import 'widgets/minimal_clean_header.dart';
import 'widgets/minimal_clean_message.dart';

/// Entry of the Minimal Clean style.
class MinimalCleanStyle extends ChatStyle {
  MinimalCleanStyle(ChatwootChatTheme theme)
    : _theme = theme,
      tokens = MinimalCleanTokens.from(theme);

  final ChatwootChatTheme _theme;
  final MinimalCleanTokens tokens;

  static const _mediaWidth = 220.0;

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
      surfaceContainer: tokens.outgoingBubble,
      surfaceContainerLow: tokens.composerFill,
      surfaceContainerHigh: tokens.outgoingBubble,
    ),
    typography: ChatTypography.standard().copyWith(
      bodyMedium: tokens.body,
      labelSmall: tokens.caption,
    ),
    shape: BorderRadius.circular(MinimalCleanTokens.bubbleRadius),
  );

  @override
  Widget buildHeader(
    BuildContext context,
    ChatHeaderData data,
    ChatwootL10n l10n,
  ) => MinimalCleanHeader(data: data, l10n: l10n, tokens: tokens);

  @override
  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ChatwootL10n l10n,
  ) => MinimalCleanComposer(
    data: data,
    l10n: l10n,
    tokens: tokens,
    horizontalPadding: _theme.horizontalPadding,
  );

  @override
  Widget buildTypingIndicator(BuildContext context, ChatwootL10n l10n) =>
      Padding(
        padding: EdgeInsetsDirectional.only(
          start: _theme.horizontalPadding + 2,
          top: 8,
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
    linkColor: tokens.accent,
  );

  @override
  Builders messageBuilders(ChatMessageEnv env) {
    final l10n = env.l10n;

    MinimalCleanMessage wrap(
      Message message,
      MessageGroupStatus? group, {
      required bool isSentByMe,
      required Widget child,
      bool bubble = true,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
    }) => MinimalCleanMessage(
      tokens: tokens,
      isSentByMe: isSentByMe,
      meta: MessageMeta.of(message, env.timeFormat, group),
      failedHint: l10n.messageFailedHint,
      bubble: bubble,
      padding: padding,
      child: child,
    );

    /// Media first, the caption (if any) in its own bubble under it.
    Widget withCaption(Widget media, String? caption, bool isSentByMe) {
      if (caption == null || caption.trim().isEmpty) return media;
      final text = _text(caption);
      return Column(
        crossAxisAlignment: isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          media,
          const SizedBox(height: 6),
          if (isSentByMe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.outgoingBubble,
                borderRadius: BorderRadius.circular(
                  MinimalCleanTokens.bubbleRadius,
                ),
              ),
              child: text,
            )
          else
            text,
        ],
      );
    }

    return Builders(
      textMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final links = findLinks(message.text);
            return wrap(
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
                      look: _linkLook,
                    ),
                  ],
                ],
              ),
            );
          },
      imageMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) => wrap(
            message,
            groupStatus,
            isSentByMe: isSentByMe,
            bubble: false,
            child: withCaption(
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ChatImageTap(
                  urls: [message.source],
                  index: 0,
                  messageId: message.id,
                  l10n: l10n,
                  enabled: message.status != MessageStatus.error,
                  child: ChatImage(
                    url: message.source,
                    width: _mediaWidth,
                    height: 156,
                    placeholderColor: tokens.media,
                    iconColor: tokens.mediaIcon,
                    semanticLabel: l10n.imageLabel,
                  ),
                ),
              ),
              message.text,
              isSentByMe,
            ),
          ),
      customMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final images = GalleryMessage.imagesOf(message);
            if (images == null) return const SizedBox.shrink();
            return wrap(
              message,
              groupStatus,
              isSentByMe: isSentByMe,
              bubble: false,
              child: withCaption(
                ImageGrid(
                  urls: images,
                  width: _mediaWidth,
                  radius: 16,
                  rowHeight: 86,
                  placeholderColor: tokens.media,
                  iconColor: tokens.mediaIcon,
                  overlayColor: const Color(0x73000000),
                  overlayStyle: tokens.title.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                  imageLabel: l10n.imageLabel,
                  messageId: message.id,
                  l10n: l10n,
                  tapEnabled: message.status != MessageStatus.error,
                ),
                GalleryMessage.captionOf(message),
                isSentByMe,
              ),
            );
          },
      fileMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) => wrap(
            message,
            groupStatus,
            isSentByMe: isSentByMe,
            padding: const EdgeInsets.all(8),
            child: FileTile(
              name: message.name,
              size: message.size,
              iconFill: isSentByMe
                  ? tokens.composerFill
                  : tokens.outgoingBubble,
              iconColor: tokens.icon,
              nameStyle: tokens.bodyStrong,
              sizeStyle: tokens.caption,
              iconRadius: 12,
            ),
          ),
      audioMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) => wrap(
            message,
            groupStatus,
            isSentByMe: isSentByMe,
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
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
              colors: AudioPlayerColors(
                buttonFill: tokens.accent,
                buttonIcon: tokens.onAccent,
                waveActive: tokens.accent,
                waveInactive: tokens.waveInactive,
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
            horizontalPadding: env.horizontalPadding + 4,
            verticalPadding: 16,
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
      decoration: TextDecoration.underline,
      decorationColor: tokens.mutedText,
    ),
  );

  LinkPreviewLook get _linkLook => LinkPreviewLook(
    fill: tokens.composerFill,
    border: tokens.composerBorder,
    thumbnailFill: tokens.media,
    iconColor: tokens.mediaIcon,
    domainStyle: tokens.caption,
    titleStyle: tokens.bodyStrong,
    descriptionStyle: tokens.status,
    radius: 14,
  );
}
