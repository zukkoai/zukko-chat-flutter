import 'package:flutter/widgets.dart';

/// Sizes of the Minimal Clean look: soft 20 px bubbles for the user only,
/// a two-row composer card.
abstract final class MinimalCleanMetrics {
  static const bubbleRadius = 20.0;
  static const userMaxWidthFactor = 0.72;
  static const agentMaxWidthFactor = 0.9;
  static const bubblePadding = EdgeInsets.symmetric(
    horizontal: 15,
    vertical: 10,
  );
  static const metaTop = 4.0;
  static const rowExtraHorizontal = 4.0;
  static const rowVertical = 16.0;
  static const rowVerticalGrouped = 6.0;

  // Media
  static const mediaWidth = 220.0;
  static const imageHeight = 156.0;
  static const mediaRadius = 16.0;
  static const galleryRowHeight = 86.0;
  static const galleryGap = 3.0;
  static const captionGap = 6.0;

  // File and audio
  static const filePadding = EdgeInsets.all(8);
  static const fileIconRadius = 12.0;
  static const audioPadding = EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6);
  static const audioButton = 34.0;
  static const linkRadius = 14.0;
  static const linkGap = 8.0;

  // Typing row
  static const typingStartExtra = 2.0;
  static const typingTop = 8.0;
  static const typingBottom = 4.0;

  // Composer
  static const composerRadius = 24.0;
  static const composerShave = 4.0;
  static const composerTop = 6.0;
  static const composerBottom = 4.0;
  static const cardPadding = EdgeInsets.fromLTRB(6, 6, 6, 2);
  static const inputPadding = EdgeInsets.symmetric(horizontal: 10);

  /// Tap targets are at least 48 dp.
  static const buttonSize = 48.0;
  static const sendIcon = 20.0;
  static const actionGap = 4.0;
  static const inputMinHeight = 48.0;

  // Header
  static const headerPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);
  static const headerButtonRadius = 12.0;
}
