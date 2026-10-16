import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../l10n/zukko_chat_l10n.dart';
import 'components.dart';

/// True when [text] has something to show.
bool hasText(String? text) => text != null && text.trim().isNotEmpty;

/// [body] as a link: underlined, optionally recolored.
TextStyle linkTextStyle(
  TextStyle body, {
  required Color decorationColor,
  Color? color,
}) => body.copyWith(
  color: color,
  decoration: TextDecoration.underline,
  decorationColor: decorationColor,
);

/// Message text with tappable links, in the style's body look.
class ChatText extends StatelessWidget {
  final String text;
  final MessageStyleSpec spec;

  /// Render Markdown (incoming messages); the visitor's own text stays plain.
  final bool markdown;

  const ChatText({
    super.key,
    required this.text,
    required this.spec,
    this.markdown = false,
  });

  @override
  Widget build(BuildContext context) => markdown
      ? MarkdownText(
          text: text,
          style: spec.tokens.body,
          linkStyle: spec.linkStyle,
        )
      : LinkifiedText(
          text: text,
          style: spec.tokens.body,
          linkStyle: spec.linkStyle,
        );
}

/// A text message: the text and, for the first link, a preview card.
class ChatTextMessage extends StatelessWidget {
  final TextMessage message;
  final bool isSentByMe;
  final MessageStyleSpec spec;

  const ChatTextMessage({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    final links = findLinks(message.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatText(text: message.text, spec: spec, markdown: !isSentByMe),
        if (links.isNotEmpty) ...[
          SizedBox(height: spec.linkGap),
          LoadedLinkPreviewCard(
            uri: links.first.uri,
            data: message.linkPreviewData,
            direction: spec.linkDirection,
            look: spec.linkLook(isSentByMe),
          ),
        ],
      ],
    );
  }
}

/// Media of [width] with its caption laid out as the style wants.
class MediaWithCaption extends StatelessWidget {
  final Widget media;
  final double width;
  final String? caption;
  final bool isSentByMe;
  final MessageStyleSpec spec;

  const MediaWithCaption({
    super.key,
    required this.media,
    required this.width,
    required this.caption,
    required this.isSentByMe,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    final text = caption;
    final c = spec.caption;
    final CrossAxisAlignment side =
        c.layout == CaptionLayout.belowBubbled && isSentByMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    switch (c.layout) {
      case CaptionLayout.inside:
        return SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              media,
              if (hasText(text))
                Padding(
                  padding: c.padding,
                  child: ChatText(text: text!, spec: spec),
                ),
            ],
          ),
        );
      case CaptionLayout.below:
      case CaptionLayout.belowBubbled:
        if (!hasText(text)) return media;
        final label = ChatText(text: text!, spec: spec);
        return Column(
          crossAxisAlignment: side,
          mainAxisSize: MainAxisSize.min,
          children: [
            media,
            SizedBox(height: c.gap),
            if (c.layout == CaptionLayout.belowBubbled && isSentByMe)
              ChatBubble(
                color: c.bubbleColor,
                radius: c.bubbleRadius,
                padding: c.bubblePadding,
                child: label,
              )
            else
              label,
          ],
        );
    }
  }
}

/// Width of the media: the style's, but never wider than the room.
class _MediaWidth extends StatelessWidget {
  final MessageStyleSpec spec;
  final Widget Function(double width) builder;

  const _MediaWidth({required this.spec, required this.builder});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        builder(math.min(spec.mediaWidth, constraints.maxWidth)),
  );
}

/// A single image, tappable for the full-screen viewer.
class ChatImageMessage extends StatelessWidget {
  final ImageMessage message;
  final bool isSentByMe;
  final MessageStyleSpec spec;
  final ZukkoChatL10n l10n;

  const ChatImageMessage({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.spec,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => _MediaWidth(
    spec: spec,
    builder: (width) {
      final tokens = spec.tokens;
      final image = ChatImageTap(
        urls: [message.source],
        index: 0,
        messageId: message.id,
        l10n: l10n,
        enabled: message.status != MessageStatus.error,
        child: ChatImage(
          url: message.source,
          width: width,
          height: spec.imageHeight,
          placeholderColor: tokens.media,
          iconColor: tokens.mediaIcon,
          semanticLabel: l10n.imageLabel,
        ),
      );
      return MediaWithCaption(
        width: width,
        caption: message.text,
        isSentByMe: isSentByMe,
        spec: spec,
        media: spec.imageRadius > 0
            ? ClipRRect(
                borderRadius: BorderRadius.circular(spec.imageRadius),
                child: image,
              )
            : image,
      );
    },
  );
}

/// Several images in a grid ("+N" on the last tile).
class ChatGalleryMessage extends StatelessWidget {
  final CustomMessage message;
  final List<String> images;
  final bool isSentByMe;
  final MessageStyleSpec spec;
  final ZukkoChatL10n l10n;

  const ChatGalleryMessage({
    super.key,
    required this.message,
    required this.images,
    required this.isSentByMe,
    required this.spec,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => _MediaWidth(
    spec: spec,
    builder: (width) {
      final tokens = spec.tokens;
      return MediaWithCaption(
        width: width,
        caption: GalleryMessage.captionOf(message),
        isSentByMe: isSentByMe,
        spec: spec,
        media: ImageGrid(
          urls: images,
          width: width,
          radius: spec.galleryRadius,
          gap: spec.galleryGap,
          rowHeight: spec.galleryRowHeight,
          placeholderColor: tokens.media,
          iconColor: tokens.mediaIcon,
          overlayColor: spec.overlay,
          overlayStyle: tokens.title.copyWith(color: const Color(0xFFFFFFFF)),
          imageLabel: l10n.imageLabel,
          messageId: message.id,
          l10n: l10n,
          tapEnabled: message.status != MessageStatus.error,
        ),
      );
    },
  );
}

/// A file attachment: icon, name and size.
class ChatFileMessage extends StatelessWidget {
  final FileMessage message;
  final bool isSentByMe;
  final MessageStyleSpec spec;
  final ZukkoChatL10n l10n;

  const ChatFileMessage({
    super.key,
    required this.message,
    required this.isSentByMe,
    required this.spec,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => FileTile(
    name: message.name,
    size: message.size,
    sizeUnits: l10n.sizeUnits,
    iconFill: spec.file.iconFill(isSentByMe),
    iconColor: spec.file.iconColor,
    nameStyle: spec.tokens.bodyStrong,
    sizeStyle: spec.tokens.caption,
    iconRadius: spec.file.iconRadius,
  );
}

/// A voice message: play button, waveform, duration.
class ChatAudioMessage extends StatelessWidget {
  final AudioMessage message;
  final MessageStyleSpec spec;
  final ZukkoChatL10n l10n;
  final AudioPlaybackController playback;

  const ChatAudioMessage({
    super.key,
    required this.message,
    required this.spec,
    required this.l10n,
    required this.playback,
  });

  @override
  Widget build(BuildContext context) => AudioPlayerBar(
    playback: playback,
    source: message.source,
    playLabel: l10n.playLabel,
    pauseLabel: l10n.pauseLabel,
    duration: message.duration,
    waveform: message.waveform ?? placeholderWaveform(message.id),
    semanticLabel: l10n.voiceMessageLabel,
    durationStyle: spec.audio.durationStyle,
    buttonSize: spec.audio.buttonSize,
    buttonRadius: spec.audio.buttonRadius,
    colors: spec.audio.colors,
  );
}
