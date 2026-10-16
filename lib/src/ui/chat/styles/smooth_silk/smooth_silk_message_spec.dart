import '../../components/components.dart';
import 'smooth_silk_metrics.dart';
import 'smooth_silk_tokens.dart';
import 'widgets/smooth_silk_bubble.dart';

/// What Smooth Silk gives the shared message builders: tonal bubbles around
/// everything, media edge to edge inside the bubble, caption under it.
MessageStyleSpec smoothSilkMessageSpec(SmoothSilkTokens t) => MessageStyleSpec(
  wrap: (slot, child) => SmoothSilkBubble(tokens: t, slot: slot, child: child),
  tokens: t,
  linkStyle: linkTextStyle(t.body, decorationColor: t.mutedText),
  mediaWidth: SmoothSilkMetrics.mediaWidth,
  imageHeight: SmoothSilkMetrics.imageHeight,
  imageRadius: 0,
  galleryRadius: 0,
  galleryRowHeight: SmoothSilkMetrics.galleryRowHeight,
  galleryGap: SmoothSilkMetrics.galleryGap,
  overlay: t.overlay,
  caption: const CaptionSpec(
    layout: CaptionLayout.inside,
    padding: SmoothSilkMetrics.captionPadding,
  ),
  linkGap: SmoothSilkMetrics.linkGap,
  linkLook: (isSentByMe) => LinkPreviewLook(
    fill: isSentByMe ? t.incomingBubble : t.background,
    thumbnailFill: t.media,
    iconColor: t.mediaIcon,
    domainStyle: t.caption,
    titleStyle: t.bodyStrong,
    descriptionStyle: t.status,
    radius: SmoothSilkMetrics.linkRadius,
  ),
  file: FileSpec(
    iconFill: (isSentByMe) => isSentByMe ? t.incomingBubble : t.outgoingBubble,
    iconColor: t.icon,
    iconRadius: SmoothSilkMetrics.fileIconRadius,
  ),
  audio: AudioSpec(
    buttonSize: SmoothSilkMetrics.audioButton,
    durationStyle: t.caption.copyWith(color: t.icon),
    colors: AudioPlayerColors(
      buttonFill: t.playFill,
      buttonIcon: t.playIcon,
      waveActive: t.waveActive,
      waveInactive: t.waveInactive,
    ),
  ),
  row: const MessageRowSpec(
    vertical: SmoothSilkMetrics.rowVertical,
    verticalGrouped: SmoothSilkMetrics.rowVerticalGrouped,
  ),
);
