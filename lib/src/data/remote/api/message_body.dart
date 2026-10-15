import 'package:dio/dio.dart';

import '../../../core/zukko_chat_upload.dart';

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
  required List<ZukkoChatUpload> files,
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
    final type = f.mediaType;
    final bytes = f.bytes;
    final file = bytes != null
        ? MultipartFile.fromBytes(bytes, filename: f.name, contentType: type)
        : await MultipartFile.fromFile(
            f.path!,
            filename: f.name,
            contentType: type,
          );
    form.files.add(MapEntry('message[attachments][]', file));
  }
  return form;
}
