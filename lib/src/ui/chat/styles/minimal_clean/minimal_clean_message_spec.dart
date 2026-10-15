import '../../components/components.dart';
import 'minimal_clean_metrics.dart';
import 'minimal_clean_tokens.dart';
import 'widgets/minimal_clean_message.dart';

/// What Minimal Clean gives the shared message builders: the user's text in
/// a soft bubble, the agent's as plain text, media without a bubble and its
/// caption under it.
MessageStyleSpec minimalCleanMessageSpec(MinimalCleanTokens t) =>
    MessageStyleSpec(
      wrap: (slot, child) =>
          MinimalCleanMessage(tokens: t, slot: slot, child: child),
      tokens: t,
      linkStyle: linkTextStyle(t.body, decorationColor: t.mutedText),
      mediaWidth: MinimalCleanMetrics.mediaWidth,
      imageHeight: MinimalCleanMetrics.imageHeight,
      imageRadius: MinimalCleanMetrics.mediaRadius,
      galleryRadius: MinimalCleanMetrics.mediaRadius,
      galleryRowHeight: MinimalCleanMetrics.galleryRowHeight,
      galleryGap: MinimalCleanMetrics.galleryGap,
      overlay: t.overlay,
      caption: CaptionSpec(
        layout: CaptionLayout.belowBubbled,
        gap: MinimalCleanMetrics.captionGap,
        bubbleColor: t.outgoingBubble,
        bubbleRadius: MinimalCleanMetrics.bubbleRadius,
        bubblePadding: MinimalCleanMetrics.bubblePadding,
      ),
      linkGap: MinimalCleanMetrics.linkGap,
      linkLook: (_) => LinkPreviewLook(
        fill: t.composerFill,
        border: t.composerBorder,
        thumbnailFill: t.media,
        iconColor: t.mediaIcon,
        domainStyle: t.caption,
        titleStyle: t.bodyStrong,
        descriptionStyle: t.status,
        radius: MinimalCleanMetrics.linkRadius,
      ),
      file: FileSpec(
        iconFill: (isSentByMe) =>
            isSentByMe ? t.composerFill : t.outgoingBubble,
        iconColor: t.icon,
        iconRadius: MinimalCleanMetrics.fileIconRadius,
      ),
      audio: AudioSpec(
        buttonSize: MinimalCleanMetrics.audioButton,
        durationStyle: t.caption,
        colors: AudioPlayerColors(
          buttonFill: t.accent,
          buttonIcon: t.onAccent,
          waveActive: t.accent,
          waveInactive: t.waveInactive,
        ),
      ),
      row: const MessageRowSpec(
        extraHorizontal: MinimalCleanMetrics.rowExtraHorizontal,
        vertical: MinimalCleanMetrics.rowVertical,
        verticalGrouped: MinimalCleanMetrics.rowVerticalGrouped,
      ),
    );
