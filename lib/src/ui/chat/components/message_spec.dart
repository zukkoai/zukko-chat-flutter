import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../theme/chat_base_tokens.dart';
import 'audio_player.dart';
import 'link_preview.dart';
import 'message_meta.dart';

/// Which kind of content a message wrapper is about to hold; the style
/// decides the bubble, padding and card per part.
enum MessagePart { text, media, file, audio }

/// Where the caption of an image or gallery goes.
enum CaptionLayout {
  /// Inside the same bubble, under the media.
  inside,

  /// Plain text under the media.
  below,

  /// Under the media; the user's captions in their own bubble.
  belowBubbled,
}

/// Everything a style's message wrapper needs about one message.
@immutable
class MessageSlot {
  final Message message;
  final MessageMeta meta;
  final bool isSentByMe;
  final MessagePart part;
  final String failedHint;

  /// Who wrote it ("You" for the user, else the agent), and their avatar.
  final String authorName;
  final String? avatarUrl;

  const MessageSlot({
    required this.message,
    required this.meta,
    required this.isSentByMe,
    required this.part,
    required this.failedHint,
    required this.authorName,
    required this.avatarUrl,
  });
}

/// Wraps the content of one message in the style's own bubble / row.
typedef MessageWrap = Widget Function(MessageSlot slot, Widget child);

/// How the caption of an image or gallery is drawn.
@immutable
class CaptionSpec {
  final CaptionLayout layout;

  /// Inside the media's bubble ([CaptionLayout.inside]).
  final EdgeInsetsGeometry padding;

  /// Between the media and the caption (the `below` layouts).
  final double gap;

  /// The user's caption bubble ([CaptionLayout.belowBubbled]).
  final Color bubbleColor;
  final double bubbleRadius;
  final EdgeInsetsGeometry bubblePadding;

  const CaptionSpec({
    required this.layout,
    this.padding = EdgeInsets.zero,
    this.gap = 0,
    this.bubbleColor = const Color(0x00000000),
    this.bubbleRadius = 0,
    this.bubblePadding = EdgeInsets.zero,
  });
}

/// A file attachment's tile.
@immutable
class FileSpec {
  final Color Function(bool isSentByMe) iconFill;
  final Color iconColor;
  final double iconRadius;

  const FileSpec({
    required this.iconFill,
    required this.iconColor,
    required this.iconRadius,
  });
}

/// A voice message's player.
@immutable
class AudioSpec {
  final double buttonSize;

  /// Null makes the play button round.
  final double? buttonRadius;
  final AudioPlayerColors colors;
  final TextStyle durationStyle;

  const AudioSpec({
    required this.buttonSize,
    required this.colors,
    required this.durationStyle,
    this.buttonRadius,
  });
}

/// How a message row sits in the list.
@immutable
class MessageRowSpec {
  /// Added to the chat's horizontal padding.
  final double extraHorizontal;
  final double vertical;
  final double verticalGrouped;

  /// Both authors start at the start edge (else the user's end at the end).
  final bool startAligned;

  const MessageRowSpec({
    required this.vertical,
    required this.verticalGrouped,
    this.extraHorizontal = 0,
    this.startAligned = false,
  });
}

/// All the values a style gives to the shared message builders: what its
/// bubbles hold and how they look. The style's own widgets are only [wrap].
@immutable
class MessageStyleSpec {
  /// The style's bubble / row around the content of a message.
  final MessageWrap wrap;
  final ChatBaseTokens tokens;

  /// Message text and its links.
  final TextStyle linkStyle;

  /// Media (image, gallery).
  final double mediaWidth;
  final double imageHeight;

  /// Corner radius of a single image (0: the bubble clips it).
  final double imageRadius;
  final double galleryRadius;
  final double galleryRowHeight;
  final double galleryGap;
  final Color overlay;
  final CaptionSpec caption;

  /// Link preview under a text message.
  final LinkPreviewLook Function(bool isSentByMe) linkLook;
  final Axis linkDirection;
  final double linkGap;

  final FileSpec file;
  final AudioSpec audio;
  final MessageRowSpec row;

  const MessageStyleSpec({
    required this.wrap,
    required this.tokens,
    required this.linkStyle,
    required this.mediaWidth,
    required this.imageHeight,
    required this.imageRadius,
    required this.galleryRadius,
    required this.galleryRowHeight,
    required this.galleryGap,
    required this.overlay,
    required this.caption,
    required this.linkLook,
    required this.linkGap,
    required this.file,
    required this.audio,
    required this.row,
    this.linkDirection = Axis.vertical,
  });
}
