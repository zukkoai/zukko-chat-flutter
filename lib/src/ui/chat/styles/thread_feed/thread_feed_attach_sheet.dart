import 'package:flutter/material.dart';

import '../../components/components.dart';
import 'thread_feed_tokens.dart';

/// Thread Feed attachment sheet: white sheet with a small radius, a close
/// button in the title row, two bordered tiles with an accent icon tile.
AttachSheetSpec threadFeedAttachSheet(ThreadFeedTokens t) => AttachSheetSpec(
  layout: AttachOptionLayout.tiles,
  hints: AttachHints.compact,
  scrim: t.sheetScrim,
  fill: t.cardFill,
  radius: const BorderRadius.vertical(top: Radius.circular(16)),
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
  gap: 14,
  handle: t.media,
  titleStyle: t.title.copyWith(fontSize: 17),
  close: AttachCloseLook(
    fill: t.fieldFill,
    icon: t.icon,
    size: 36,
    radius: 10,
    iconSize: 18,
  ),
  labelStyle: t.bodyStrong.copyWith(fontSize: 15),
  hintStyle: t.caption,
  optionFill: t.cardFill,
  optionBorder: t.cardBorder,
  optionRadius: 12,
  optionPadding: const EdgeInsets.all(14),
  optionGap: 12,
  discFill: t.micFill,
  discSize: 40,
  discRadius: 10,
  iconColor: t.micIcon,
  iconSize: 20,
  imageIcon: Icons.image_outlined,
  fileIcon: Icons.attach_file_rounded,
  noteStyle: t.caption,
  noteAlign: TextAlign.start,
);
