import 'package:dio/dio.dart' show DioMediaType, MultipartFile;
import 'package:flutter/foundation.dart';

/// A file to send with a message: a picked image or document, or a voice
/// recording. Either a [path] on disk (mobile, desktop) or the [bytes]
/// (web, recordings). The [name]'s extension decides the content type.
@immutable
class ZukkoChatUpload {
  /// Server limit per attachment.
  static const maxSizeMb = 40;
  static const maxSize = maxSizeMb * 1024 * 1024;

  /// Server limit of message text, in characters.
  static const maxMessageLength = 150000;

  /// Server limit of attachments per message.
  static const maxAttachments = 15;

  /// Types the server accepts besides any `image/`, `video/` and `audio/`.
  static const acceptedDocumentTypes = {
    'text/csv',
    'text/plain',
    'text/rtf',
    'application/json',
    'application/pdf',
    'application/zip',
    'application/x-7z-compressed',
    'application/vnd.rar',
    'application/x-tar',
    'application/msword',
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint',
    'application/rtf',
    'application/vnd.oasis.opendocument.text',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  final String name;
  final String? path;
  final Uint8List? bytes;
  final int? _size;

  const ZukkoChatUpload.file({
    required this.name,
    required String this.path,
    this._size,
  }) : bytes = null;

  const ZukkoChatUpload.bytes({
    required this.name,
    required Uint8List this.bytes,
  }) : path = null,
       _size = null;

  /// Size in bytes, when known.
  int? get size => bytes?.length ?? _size;

  /// Content type guessed from the file name; null when unknown.
  DioMediaType? get mediaType => MultipartFile.lookupMediaType(name);

  /// `type/subtype` from the file name, e.g. `image/png`; null when unknown.
  String? get mimeType => mediaType?.mimeType;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;

  /// Whether the server accepts this file's type (guessed from the name).
  bool get isTypeAccepted =>
      isImage || isAudio || isVideo || acceptedDocumentTypes.contains(mimeType);

  bool get isTooLarge => (size ?? 0) > maxSize;
}
