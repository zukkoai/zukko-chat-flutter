import 'package:flutter/widgets.dart';

/// Sizes of the Smooth Silk look: large even radii, generous padding.
abstract final class SmoothSilkMetrics {
  static const bubbleRadius = 24.0;
  static const maxWidthFactor = 0.78;
  static const bubblePadding = EdgeInsets.symmetric(
    horizontal: 17,
    vertical: 12,
  );
  static const metaPadding = EdgeInsets.fromLTRB(14, 4, 14, 0);
  static const rowVertical = 10.0;
  static const rowVerticalGrouped = 4.0;

  // Media
  static const mediaWidth = 240.0;
  static const imageHeight = 170.0;
  static const galleryRowHeight = 96.0;
  static const galleryGap = 3.0;
  static const captionPadding = EdgeInsets.fromLTRB(16, 10, 16, 12);

  // File and audio
  static const filePadding = EdgeInsets.all(10);
  static const fileIconRadius = 14.0;
  static const audioPadding = EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8);
  static const audioButton = 38.0;
  static const linkRadius = 16.0;
  static const linkGap = 10.0;

  // Typing row
  static const typingTop = 4.0;
  static const typingPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 15,
  );

  // Composer
  static const composerHeight = 54.0;
  static const composerShave = 2.0;
  static const composerTop = 8.0;
  static const composerBottom = 6.0;
  static const pillPadding = EdgeInsets.symmetric(horizontal: 5, vertical: 4);

  /// Tap targets are at least 48 dp.
  static const buttonSize = 48.0;
  static const hiddenAttachWidth = 12.0;
  static const attachGap = 6.0;
  static const micAbsentWidth = 8.0;
  static const sendGap = 8.0;
  static const sendIcon = 22.0;
  static const inputMinHeight = 48.0;

  // Header
  static const headerPadding = EdgeInsetsDirectional.fromSTEB(4, 6, 6, 6);
}
