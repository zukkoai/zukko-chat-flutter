import 'package:flutter/widgets.dart';

import '../../components/components.dart';
import 'thread_feed_metrics.dart';
import 'thread_feed_tokens.dart';
import 'widgets/thread_feed_row.dart';

/// What Thread Feed gives the shared message builders: full-width rows, no
/// bubbles; files and voice messages in a card, captions as plain text.
MessageStyleSpec threadFeedMessageSpec(ThreadFeedTokens t) => MessageStyleSpec(
  wrap: (slot, child) => ThreadFeedRow(tokens: t, slot: slot, child: child),
  tokens: t,
  linkStyle: linkTextStyle(t.body, color: t.link, decorationColor: t.link),
  mediaWidth: ThreadFeedMetrics.mediaWidth,
  imageHeight: ThreadFeedMetrics.imageHeight,
  imageRadius: ThreadFeedMetrics.radius,
  galleryRadius: ThreadFeedMetrics.radius,
  galleryRowHeight: ThreadFeedMetrics.galleryRowHeight,
  galleryGap: ThreadFeedMetrics.galleryGap,
  overlay: t.overlay,
  caption: const CaptionSpec(
    layout: CaptionLayout.below,
    gap: ThreadFeedMetrics.captionGap,
  ),
  linkDirection: Axis.horizontal,
  linkGap: ThreadFeedMetrics.linkGap,
  linkLook: (_) => LinkPreviewLook(
    fill: t.cardFill,
    border: t.cardBorder,
    thumbnailFill: t.media,
    iconColor: t.mediaIcon,
    domainStyle: t.caption,
    titleStyle: t.bodyStrong,
    descriptionStyle: t.caption.copyWith(color: t.text),
    radius: ThreadFeedMetrics.radius,
  ),
  file: FileSpec(
    iconFill: (_) => t.fieldFill,
    iconColor: t.accent,
    iconRadius: ThreadFeedMetrics.fileIconRadius,
  ),
  audio: AudioSpec(
    buttonSize: ThreadFeedMetrics.audioButton,
    buttonRadius: ThreadFeedMetrics.audioButtonRadius,
    durationStyle: t.caption,
    colors: AudioPlayerColors(
      buttonFill: t.accent,
      buttonIcon: t.onAccent,
      waveActive: t.accent,
      waveInactive: t.waveInactive,
    ),
  ),
  row: const MessageRowSpec(
    startAligned: true,
    vertical: ThreadFeedMetrics.rowVertical,
    verticalGrouped: ThreadFeedMetrics.rowVerticalGrouped,
  ),
);
