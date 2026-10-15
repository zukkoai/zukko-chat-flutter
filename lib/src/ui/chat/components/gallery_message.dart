import 'package:flutter_chat_core/flutter_chat_core.dart';

/// A message with several images, carried as a [CustomMessage] (the chat
/// core has no multi-image type). The controller creates it, styles read it.
abstract final class GalleryMessage {
  static const _kind = 'chatwoot.gallery';

  static CustomMessage create({
    required String id,
    required String authorId,
    required List<String> images,
    String? caption,
    DateTime? createdAt,
    MessageStatus? status,
  }) => CustomMessage(
    id: id,
    authorId: authorId,
    createdAt: createdAt,
    status: status,
    metadata: {'kind': _kind, 'images': images, 'caption': ?caption},
  );

  /// The image urls, or null when [message] is not a gallery.
  static List<String>? imagesOf(Message message) {
    if (message is! CustomMessage) return null;
    final meta = message.metadata;
    if (meta == null || meta['kind'] != _kind) return null;
    final images = meta['images'];
    if (images is! List) return null;
    return [
      for (final i in images)
        if (i is String) i,
    ];
  }

  static String? captionOf(Message message) {
    final caption = message.metadata?['caption'];
    return caption is String ? caption : null;
  }
}
