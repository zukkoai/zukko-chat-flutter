import 'package:flutter/widgets.dart';

/// Sizes of the Thread Feed look: full-width rows, 10-12 px corners.
abstract final class ThreadFeedMetrics {
  static const radius = 12.0;
  static const avatarSize = 34.0;
  static const avatarGap = 12.0;
  static const rowAvatarRadius = 10.0;
  static const nameGap = 3.0;
  static const timeGap = 8.0;
  static const failedHintTop = 4.0;
  static const rowVertical = 14.0;
  static const rowVerticalGrouped = 6.0;

  // Media
  static const mediaWidth = 260.0;
  static const imageHeight = 172.0;
  static const galleryRowHeight = 84.0;
  static const galleryGap = 4.0;
  static const captionGap = 8.0;

  // File and audio
  static const cardPadding = EdgeInsets.all(8);
  static const fileIconRadius = 8.0;
  static const audioPadding = EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6);
  static const audioRadius = 10.0;
  static const audioButton = 34.0;
  static const audioButtonRadius = 8.0;
  static const linkGap = 8.0;

  // Typing row
  static const typingTop = 6.0;
  static const typingBottom = 4.0;

  // Composer
  static const composerHeight = 50.0;
  static const composerShave = 4.0;
  static const composerTop = 10.0;
  static const composerBottom = 4.0;
  static const fieldPadding = EdgeInsetsDirectional.fromSTEB(3, 1, 5, 1);

  /// Tap targets are at least 48 dp.
  static const attachSize = 48.0;
  static const attachRadius = 10.0;
  static const attachGap = 2.0;
  static const hiddenAttachWidth = 12.0;
  static const sendSize = 48.0;
  static const sendRadius = 9.0;
  static const sendIcon = 19.0;
  static const sendGap = 6.0;
  static const micGap = 8.0;
  static const micIcon = 23.0;
  static const inputMinHeight = 48.0;

  // Recording (hint row above the field and the mic tile)
  static const recHintPadding = EdgeInsetsDirectional.only(start: 4);
  static const recHintGap = 10.0;
  static const recFieldPadding = EdgeInsets.symmetric(horizontal: 14);
  static const recMic = 56.0;
  static const recMicIcon = 24.0;
  static const recDot = 8.0;
  static const recBarWidth = 3.0;
  static const recBarRadius = 1.5;
  static const recBarMax = 22.0;
  static const recBarStrip = 26.0;
  static const recHintSize = 13.0;
  static const recChevron = 15.0;

  // Header
  static const headerPadding = EdgeInsetsDirectional.fromSTEB(4, 6, 6, 6);
  static const headerAvatarRadius = 12.0;
  static const headerButtonRadius = 10.0;
}
