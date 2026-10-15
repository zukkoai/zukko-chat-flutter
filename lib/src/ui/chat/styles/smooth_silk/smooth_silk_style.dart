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
import 'smooth_silk_tokens.dart';
import 'widgets/smooth_silk_bubble.dart';
import 'widgets/smooth_silk_composer.dart';
import 'widgets/smooth_silk_header.dart';

/// Entry of the Smooth Silk style.
class SmoothSilkStyle extends ChatStyle {
  SmoothSilkStyle(ZukkoChatTheme theme)
    : _theme = theme,
      tokens = SmoothSilkTokens.from(theme);

  final ZukkoChatTheme _theme;
  final SmoothSilkTokens tokens;

  static const _mediaWidth = 240.0;

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
      surfaceContainer: tokens.incomingBubble,
      surfaceContainerLow: tokens.composerFill,
      surfaceContainerHigh: tokens.outgoingBubble,
    ),
    typography: ChatTypography.standard().copyWith(
      bodyMedium: tokens.body,
      labelSmall: tokens.caption,
    ),
    shape: BorderRadius.circular(SmoothSilkTokens.bubbleRadius),
  );

  @override
  Widget buildHeader(
    BuildContext context,
    ChatHeaderData data,
    ZukkoChatL10n l10n,
  ) => SmoothSilkHeader(data: data, l10n: l10n, tokens: tokens);

  @override
  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ZukkoChatL10n l10n,
  ) => SmoothSilkComposer(
    data: data,
    l10n: l10n,
    tokens: tokens,
    horizontalPadding: _theme.horizontalPadding,
  );

  @override
  Widget buildTypingIndicator(BuildContext context, ZukkoChatL10n l10n) =>
      Padding(
        padding: EdgeInsetsDirectional.only(
          start: _theme.horizontalPadding,
          top: 4,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: tokens.incomingBubble,
              borderRadius: BorderRadius.circular(
                SmoothSilkTokens.bubbleRadius,
              ),
            ),
            child: TypingIndicator(
              color: tokens.typingDot,
              semanticLabel: l10n.typingText,
            ),
          ),
        ),
      );

  @override
  Widget buildFooter(BuildContext context, ZukkoChatL10n l10n) => PoweredBy(
    prefix: l10n.poweredByText,
    style: tokens.caption,
    linkColor: tokens.accent,
  );

  @override
  Builders messageBuilders(ChatMessageEnv env) {
    final l10n = env.l10n;

    SmoothSilkBubble bubble(
      Message message,
      MessageGroupStatus? group, {
      required bool isSentByMe,
      required Widget child,
      EdgeInsetsGeometry? padding,
    }) => SmoothSilkBubble(
      tokens: tokens,
      isSentByMe: isSentByMe,
      meta: MessageMeta.of(message, env.timeFormat, group),
      failedHint: l10n.messageFailedHint,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
      child: child,
    );

    Widget caption(String? text) => text == null || text.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _text(text),
          );

    return Builders(
      textMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final links = findLinks(message.text);
            return bubble(
              message,
              groupStatus,
              isSentByMe: isSentByMe,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _text(message.text),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LinkPreviewCard(
                      uri: links.first.uri,
                      data: message.linkPreviewData,
                      look: _linkLook(isSentByMe: isSentByMe),
                    ),
                  ],
                ],
              ),
            );
          },
      imageMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) =>
              bubble(
                message,
                groupStatus,
                isSentByMe: isSentByMe,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: _mediaWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatImageTap(
                        urls: [message.source],
                        index: 0,
                        messageId: message.id,
                        l10n: l10n,
                        enabled: message.status != MessageStatus.error,
                        child: ChatImage(
                          url: message.source,
                          height: 170,
                          placeholderColor: tokens.media,
                          iconColor: tokens.mediaIcon,
                          semanticLabel: l10n.imageLabel,
                        ),
                      ),
                      caption(message.text),
                    ],
                  ),
                ),
              ),
      customMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final images = GalleryMessage.imagesOf(message);
            if (images == null) return const SizedBox.shrink();
            return bubble(
              message,
              groupStatus,
              isSentByMe: isSentByMe,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: _mediaWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ImageGrid(
                      urls: images,
                      width: _mediaWidth,
                      radius: 0,
                      placeholderColor: tokens.media,
                      iconColor: tokens.mediaIcon,
                      overlayColor: const Color(0x66000000),
                      overlayStyle: tokens.title.copyWith(
                        color: const Color(0xFFFFFFFF),
                      ),
                      imageLabel: l10n.imageLabel,
                      messageId: message.id,
                      l10n: l10n,
                      tapEnabled: message.status != MessageStatus.error,
                    ),
                    caption(GalleryMessage.captionOf(message)),
                  ],
                ),
              ),
            );
          },
      fileMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) =>
              bubble(
                message,
                groupStatus,
                isSentByMe: isSentByMe,
                padding: const EdgeInsets.all(10),
                child: FileTile(
                  name: message.name,
                  size: message.size,
                  iconFill: isSentByMe
                      ? tokens.incomingBubble
                      : tokens.outgoingBubble,
                  iconColor: tokens.icon,
                  nameStyle: tokens.bodyStrong,
                  sizeStyle: tokens.caption,
                  iconRadius: 14,
                ),
              ),
      audioMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) =>
              bubble(
                message,
                groupStatus,
                isSentByMe: isSentByMe,
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
                child: AudioPlayerBar(
                  playback: env.audio,
                  source: message.source,
                  playLabel: l10n.playLabel,
                  pauseLabel: l10n.pauseLabel,
                  duration: message.duration,
                  waveform: message.waveform ?? placeholderWaveform(message.id),
                  semanticLabel: l10n.voiceMessageLabel,
                  durationStyle: tokens.caption.copyWith(color: tokens.icon),
                  buttonSize: 38,
                  colors: AudioPlayerColors(
                    buttonFill: tokens.playFill,
                    buttonIcon: tokens.playIcon,
                    waveActive: tokens.waveActive,
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
            horizontalPadding: env.horizontalPadding,
            verticalPadding: 10,
            verticalGroupedPadding: 4,
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

  LinkPreviewLook _linkLook({required bool isSentByMe}) => LinkPreviewLook(
    fill: isSentByMe ? tokens.incomingBubble : tokens.background,
    thumbnailFill: tokens.media,
    iconColor: tokens.mediaIcon,
    domainStyle: tokens.caption,
    titleStyle: tokens.bodyStrong,
    descriptionStyle: tokens.status,
    radius: 16,
  );
}
