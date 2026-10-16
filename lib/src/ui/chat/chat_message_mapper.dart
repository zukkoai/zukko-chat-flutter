import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../core/zukko_chat_upload.dart';
import '../../data/models/zukko_chat_message.dart';
import '../../shared/url_policy.dart';
import '../l10n/zukko_chat_l10n.dart';
import 'components/gallery_message.dart';

/// Author id of the user's own messages.
const chatMeId = 'zukko-me';

/// Author id of an agent without an id of its own.
const chatAgentId = 'zukko-agent';

/// Author id of generated system lines (conversation resolved).
const chatSystemId = 'zukko-system';

/// A server message as the chat list shows it.
typedef MappedMessage = ({Message message, User? author});

/// Turns server messages and local sends into flutter_chat_core [Message]s.
/// Pure: it holds no chat state, only the strings it needs.
class ChatMessageMapper {
  ChatMessageMapper(this.l10n);

  /// Strings of generated text; the view keeps it current.
  ZukkoChatL10n l10n;

  /// Maps [m] under the list key [key]; null when it must not be shown
  /// (activity / template lines, or nothing to show). [fallbackCreatedAt]
  /// is used when the server date cannot be parsed.
  ///
  /// Attachments with an https url become an image, a gallery (several
  /// images), an audio or a file message, with the text as caption; others
  /// fall back to a text message with [ZukkoChatL10n.attachmentLabel]. The
  /// author of an agent message comes back so the caller can remember it.
  MappedMessage? fromServer(
    ZukkoChatMessage m, {
    required String key,
    DateTime? fallbackCreatedAt,
  }) {
    if (m.isActivity || m.isTemplate) return null;
    final content = (m.content ?? '').trim().isNotEmpty ? m.content : null;
    final attachments = [
      for (final raw in m.attachments ?? const <dynamic>[])
        ?_Attachment.tryParse(raw),
    ];
    final hasAttachments = m.attachments?.isNotEmpty ?? false;
    if (content == null && !hasAttachments) return null;

    final String authorId;
    User? author;
    if (m.messageType == ZukkoChatMessage.typeFromAgent) {
      final sender = m.sender;
      authorId = sender?.id == null ? chatAgentId : 'agent:${sender!.id}';
      // Server-controlled URL: https only, no 404 placeholder.
      final avatar = safeAvatarUrl(sender?.avatarUrl ?? sender?.thumbnail);
      author = User(id: authorId, name: sender?.name, imageSource: avatar);
    } else {
      authorId = chatMeId;
    }
    final createdAt =
        DateTime.tryParse(m.createdAt)?.toUtc() ??
        fallbackCreatedAt ??
        DateTime.now().toUtc();
    final status = authorId == chatMeId ? MessageStatus.seen : null;
    final message = _build(
      key: key,
      authorId: authorId,
      content: content,
      attachments: attachments,
      createdAt: createdAt,
      status: status,
    );
    return (message: message, author: author);
  }

  Message _build({
    required String key,
    required String authorId,
    required String? content,
    required List<_Attachment> attachments,
    required DateTime createdAt,
    required MessageStatus? status,
  }) {
    final images = [
      for (final a in attachments)
        if (a.kind == _AttachmentKind.image) a.url,
    ];
    if (images.length > 1) {
      return GalleryMessage.create(
        id: key,
        authorId: authorId,
        images: images,
        caption: content,
        createdAt: createdAt,
        status: status,
      );
    }
    if (images.length == 1) {
      return ImageMessage(
        id: key,
        authorId: authorId,
        source: images.single,
        text: content,
        createdAt: createdAt,
        status: status,
      );
    }
    final first = attachments.firstOrNull;
    if (first != null && first.kind == _AttachmentKind.audio) {
      return AudioMessage(
        id: key,
        authorId: authorId,
        source: first.url,
        duration: Duration.zero,
        text: content,
        size: first.size,
        createdAt: createdAt,
        status: status,
      );
    }
    if (first != null) {
      return FileMessage(
        id: key,
        authorId: authorId,
        source: first.url,
        name: first.name ?? l10n.attachmentLabel,
        size: first.size,
        createdAt: createdAt,
        status: status,
      );
    }
    return TextMessage(
      id: key,
      authorId: authorId,
      text: content ?? l10n.attachmentLabel,
      createdAt: createdAt,
      status: status,
    );
  }

  /// The bubble shown at once for [files] being sent (image, gallery, voice
  /// or file). [audioDuration] is the length of a recording.
  Message localPreview(
    String id,
    List<ZukkoChatUpload> files,
    Duration? audioDuration,
  ) {
    final createdAt = DateTime.now().toUtc();
    const status = MessageStatus.sending;
    // A local path shows the image before the upload ends; the web has none.
    final first = files.first;
    if (files.length > 1 && files.every((f) => f.isImage)) {
      return GalleryMessage.create(
        id: id,
        authorId: chatMeId,
        images: [for (final f in files) f.path ?? ''],
        createdAt: createdAt,
        status: status,
      );
    }
    if (first.isImage) {
      return ImageMessage(
        id: id,
        authorId: chatMeId,
        source: first.path ?? '',
        createdAt: createdAt,
        status: status,
      );
    }
    if (first.isAudio) {
      return AudioMessage(
        id: id,
        authorId: chatMeId,
        source: first.path ?? '',
        duration: audioDuration ?? Duration.zero,
        size: first.size,
        createdAt: createdAt,
        status: status,
      );
    }
    return FileMessage(
      id: id,
      authorId: chatMeId,
      source: first.path ?? '',
      name: first.name,
      size: first.size,
      createdAt: createdAt,
      status: status,
    );
  }
}

enum _AttachmentKind { image, audio, file }

/// One entry of a message's `attachments` (`file_type`, `data_url`,
/// `file_size`).
class _Attachment {
  final _AttachmentKind kind;
  final String url;
  final String? name;
  final int? size;

  const _Attachment(this.kind, this.url, this.name, this.size);

  /// Null unless [raw] is a map with an https `data_url`.
  static _Attachment? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['data_url'];
    if (url is! String || !isHttpsUrl(url)) return null;
    final size = raw['file_size'];
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    return _Attachment(
      switch (raw['file_type']) {
        'image' => _AttachmentKind.image,
        'audio' => _AttachmentKind.audio,
        _ => _AttachmentKind.file,
      },
      url,
      segments.isEmpty ? null : segments.last,
      size is int ? size : null,
    );
  }
}
