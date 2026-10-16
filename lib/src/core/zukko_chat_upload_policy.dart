import 'dart:io';

import 'zukko_chat_client_exception.dart';
import 'zukko_chat_upload.dart';

// Server: app/models/attachment.rb:27-36 (ACCEPTABLE_FILE_TYPES) and :179-189
// (any image/, video/, audio/ type is accepted too); size cap at :184.
const _allowedMimeTypes = {
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

/// Throws `SEND_MESSAGE_FAILED` when the server would reject [f] (type or
/// size). A file given by path of unknown size is measured on disk first, so an
/// oversized file is never read.
Future<void> validateUpload(ZukkoChatUpload f) async {
  final mime = f.mimeType;
  final typeOk =
      mime != null &&
      (f.isImage || f.isVideo || f.isAudio || _allowedMimeTypes.contains(mime));
  if (!typeOk) _reject('File type not supported: ${f.name}');
  final path = f.path;
  final size = f.size ?? (path == null ? null : await File(path).length());
  if ((size ?? 0) > ZukkoChatUpload.maxSize) {
    _reject('File is larger than ${ZukkoChatUpload.maxSizeMb} MB: ${f.name}');
  }
}

Never _reject(String message) =>
    throw ZukkoChatException(message, ZukkoChatExceptionType.sendMessageFailed);
