import 'package:flutter/material.dart';

import '../../components/components.dart';
import 'smooth_silk_tokens.dart';

/// Smooth Silk attachment sheet: rounded pearl sheet, two soft cards with an
/// icon disc, a limit note and a pill cancel button.
AttachSheetSpec smoothSilkAttachSheet(SmoothSilkTokens t) => AttachSheetSpec(
  layout: AttachOptionLayout.cards,
  hints: AttachHints.standard,
  scrim: t.sheetScrim,
  fill: t.incomingBubble,
  radius: const BorderRadius.vertical(top: Radius.circular(28)),
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
  gap: 16,
  handle: t.media,
  titleStyle: t.title.copyWith(fontSize: 17),
  titlePadding: const EdgeInsets.symmetric(horizontal: 4),
  labelStyle: t.bodyStrong,
  hintStyle: t.status,
  optionFill: t.background,
  optionRadius: 22,
  optionPadding: const EdgeInsets.all(16),
  optionGap: 12,
  discFill: t.outgoingBubble,
  discSize: 48,
  discRadius: 24,
  iconColor: t.accent,
  iconSize: 22,
  imageIcon: Icons.image_outlined,
  fileIcon: Icons.insert_drive_file_outlined,
  noteStyle: t.caption.copyWith(fontSize: 12),
  cancel: AttachCancelLook(
    fill: t.background,
    style: t.bodyStrong,
    height: 52,
    radius: 26,
  ),
);
