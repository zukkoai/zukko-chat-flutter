import 'package:flutter/material.dart';

import '../../components/components.dart';
import 'minimal_clean_tokens.dart';

/// Minimal Clean attachment sheet: a floating white group (title, two rows)
/// and a separate cancel button, like a native action sheet.
AttachSheetSpec minimalCleanAttachSheet(MinimalCleanTokens t) =>
    AttachSheetSpec(
      layout: AttachOptionLayout.list,
      hints: AttachHints.descriptive,
      titleWithLimit: true,
      scrim: t.sheetScrim,
      fill: t.composerFill,
      radius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 26),
      gap: 8,
      titleStyle: t.status.copyWith(fontSize: 13),
      titlePadding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      labelStyle: t.body.copyWith(fontSize: 16, height: 1.3),
      hintStyle: t.status.copyWith(fontSize: 12.5),
      optionFill: Colors.transparent,
      optionRadius: 0,
      optionPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      optionGap: 14,
      divider: t.divider,
      rowHeight: 62,
      discFill: Colors.transparent,
      discSize: 22,
      discRadius: 0,
      iconColor: t.text,
      iconSize: 22,
      imageIcon: Icons.image_outlined,
      fileIcon: Icons.insert_drive_file_outlined,
      cancel: AttachCancelLook(
        fill: t.composerFill,
        style: t.bodyStrong.copyWith(fontSize: 16),
        height: 56,
        radius: 20,
      ),
    );
