import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter/foundation.dart';

/// A file to send with a message: a picked image or document, or a voice
/// recording. Either a [path] on disk (mobile, desktop) or the [bytes]
/// (web, recordings). The [name]'s extension decides the content type.
@immutable
class ZukkoChatUpload {
  /// Server limit per attachment.
  static const maxSize = 40 * 1024 * 1024;

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

  /// `type/subtype` from the file name, e.g. `image/png`; null when unknown.
  String? get mimeType => MultipartFile.lookupMediaType(name)?.mimeType;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;
  bool get isTooLarge => (size ?? 0) > maxSize;
}
