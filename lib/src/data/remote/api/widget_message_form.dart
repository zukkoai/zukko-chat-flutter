import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';
import '../../../core/chatwoot_upload.dart';

// Server: app/models/attachment.rb:27-36 (ACCEPTABLE_FILE_TYPES) and :179-189
// (any image/, video/, audio/ type is accepted too); size cap 40 MB at :184.
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

String _timestamp(DateTime? now) =>
    (now ?? DateTime.now()).toUtc().toIso8601String();

/// JSON body of `POST /messages` (text only). `referer_url` is always sent:
/// the server reads it when it auto-creates the conversation.
Map<String, dynamic> buildMessageJson({
  required String content,
  required String echoId,
  int? replyTo,
  DateTime? now,
}) => {
  'message': {
    'content': content,
    'referer_url': '',
    'timestamp': _timestamp(now),
    'echo_id': echoId,
    'reply_to': ?replyTo,
  },
};

/// Multipart body of `POST /messages` with attachments.
Future<FormData> buildMessageForm({
  required String content,
  required String echoId,
  required List<ChatwootUpload> files,
  int? replyTo,
  DateTime? now,
}) async {
  final form = FormData();
  if (content.isNotEmpty) {
    form.fields.add(MapEntry('message[content]', content));
  }
  form.fields
    ..add(const MapEntry('message[referer_url]', ''))
    ..add(MapEntry('message[timestamp]', _timestamp(now)))
    ..add(MapEntry('message[echo_id]', echoId));
  if (replyTo != null) {
    form.fields.add(MapEntry('message[reply_to]', '$replyTo'));
  }
  for (final f in files) {
    final type = MultipartFile.lookupMediaType(f.name);
    final file = f.bytes != null
        ? MultipartFile.fromBytes(f.bytes!, filename: f.name, contentType: type)
        : await MultipartFile.fromFile(
            f.path!,
            filename: f.name,
            contentType: type,
          );
    form.files.add(MapEntry('message[attachments][]', file));
  }
  return form;
}

/// [validateUpload] for a file whose size is unknown (a path upload): asks the
/// file system for the length first, so an oversized file is never read.
Future<void> validateUploadFile(ChatwootUpload f) async {
  final path = f.path;
  if (f.size == null && path != null) {
    final size = (await MultipartFile.fromFile(path)).length;
    if (size > ChatwootUpload.maxSize) {
      throw ChatwootClientException(
        'File is larger than 40 MB: ${f.name}',
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
      );
    }
  }
  validateUpload(f);
}

/// Throws SEND_MESSAGE_FAILED when the server would reject [f] (size or type).
/// A file of unknown size passes here; see [validateUploadFile].
void validateUpload(ChatwootUpload f) {
  final mime = f.mimeType;
  final typeOk =
      mime != null &&
      (mime.startsWith('image/') ||
          mime.startsWith('video/') ||
          mime.startsWith('audio/') ||
          _allowedMimeTypes.contains(mime));
  if (!typeOk) {
    throw ChatwootClientException(
      'File type not supported: ${f.name}',
      ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
    );
  }
  if (f.isTooLarge) {
    throw ChatwootClientException(
      'File is larger than 40 MB: ${f.name}',
      ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
    );
  }
}
