import 'package:equatable/equatable.dart';

import '../../shared/json_converters.dart';

/// One file of a message (`attachments[]` of the widget message payload).
///
/// Parsing is tolerant: a missing or wrongly typed field is `null`. Not a
/// Hive type: messages store attachments as plain JSON maps.
///
/// {@category FlutterClientSdk}
class ZukkoChatAttachment extends Equatable {
  const ZukkoChatAttachment({
    this.id,
    this.messageId,
    this.fileType,
    this.accountId,
    this.extension,
    this.dataUrl,
    this.thumbUrl,
    this.externalUrl,
    this.fileSize,
    this.width,
    this.height,
  });

  final int? id;
  final int? messageId;

  /// `image`, `audio`, `video`, `file`, `location`, ...
  final String? fileType;
  final int? accountId;
  final String? extension;

  /// The file's URL.
  final String? dataUrl;
  final String? thumbUrl;
  final String? externalUrl;

  /// Size in bytes.
  final int? fileSize;
  final int? width;
  final int? height;

  factory ZukkoChatAttachment.fromJson(Map<String, dynamic> json) {
    String? str(String k) => json[k] is String ? json[k] as String : null;
    return ZukkoChatAttachment(
      id: intFromJson(json['id']),
      messageId: intFromJson(json['message_id']),
      fileType: str('file_type'),
      accountId: intFromJson(json['account_id']),
      extension: str('extension'),
      dataUrl: str('data_url'),
      thumbUrl: str('thumb_url'),
      externalUrl: str('external_url'),
      fileSize: intFromJson(json['file_size']),
      width: intFromJson(json['width']),
      height: intFromJson(json['height']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'message_id': messageId,
    'file_type': fileType,
    'account_id': accountId,
    'extension': extension,
    'data_url': dataUrl,
    'thumb_url': thumbUrl,
    'external_url': externalUrl,
    'file_size': fileSize,
    'width': width,
    'height': height,
  };

  @override
  List<Object?> get props => [
    id,
    messageId,
    fileType,
    accountId,
    extension,
    dataUrl,
    thumbUrl,
    externalUrl,
    fileSize,
    width,
    height,
  ];
}

/// Parses `attachments`: `null` unless [data] is a list; elements that are not
/// JSON objects are skipped.
List<ZukkoChatAttachment>? attachmentsFromJson(Object? data) {
  if (data is! List) return null;
  return [
    for (final e in data)
      if (e is Map) ZukkoChatAttachment.fromJson(Map<String, dynamic>.from(e)),
  ];
}

/// A free-form JSON object as `Map<String, dynamic>`; `null` for anything
/// else. Accepts the `Map<dynamic, dynamic>` Hive returns.
Map<String, dynamic>? jsonMapFromJson(Object? data) =>
    data is Map ? Map<String, dynamic>.from(data) : null;
