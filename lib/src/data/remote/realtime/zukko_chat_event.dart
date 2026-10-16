import '../../../shared/json_converters.dart';
import '../../models/zukko_chat_message.dart';

/// One `message` of an ActionCable frame: the event name and its payload.
class ZukkoChatEventMessage {
  ZukkoChatEventMessage({this.data, this.event});

  /// Reads `{event: <wire name>, data: {...}}`. Never throws: an unknown event
  /// is `null`, a payload that is not a map is `null`.
  factory ZukkoChatEventMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return ZukkoChatEventMessage(
      data: data is Map<String, dynamic>
          ? ZukkoChatEventMessageData(data)
          : null,
      event: ZukkoChatEventMessageType.byWire(json['event']),
    );
  }

  final ZukkoChatEventMessageData? data;

  /// `null` for events this SDK does not know.
  final ZukkoChatEventMessageType? event;
}

/// The payload of a `message.*` / typing / presence / conversation event. The
/// raw map is kept and read through tolerant getters (the server is untrusted
/// and inconsistent about types), so one odd field never drops the event.
class ZukkoChatEventMessageData {
  ZukkoChatEventMessageData(this.raw);

  final Map<String, dynamic> raw;

  /// Id of the message (message events) or the conversation (conversation
  /// events).
  int? get id => intFromJson(raw['id']);

  /// The `echo_id` the sender chose; set on the confirmation of our own send.
  String? get echoId =>
      raw['echo_id'] is String ? raw['echo_id'] as String : null;

  /// `message_type` of a message event.
  int? get messageType => intFromJson(raw['message_type']);

  /// A private note (message events).
  bool? get private => raw['private'] is bool ? raw['private'] as bool : null;

  /// Set on typing events: a typing indicator of a private note.
  bool? get isPrivate =>
      raw['is_private'] is bool ? raw['is_private'] as bool : null;

  /// Conversation status (`conversation.*` events).
  String? get status =>
      raw['status'] is String ? raw['status'] as String : null;

  /// Presence payload: user id to `online` / `offline`.
  Object? get users => raw['users'];

  /// Inbox of a conversation payload.
  int? get inboxId => intFromJson(raw['inbox_id']);

  /// The payload as a [ZukkoChatMessage]. A malformed `attachments` or
  /// `sender` value is dropped instead of losing the whole message.
  ZukkoChatMessage toMessage() {
    final json = {...raw};
    if (json['attachments'] is! List) json.remove('attachments');
    if (json['sender'] is! Map<String, dynamic>) json.remove('sender');
    return ZukkoChatMessage.fromJson(json);
  }
}

/// Server events a contact receives, with their wire names.
enum ZukkoChatEventMessageType {
  presence_update('presence.update'),
  message_created('message.created'),
  message_updated('message.updated'),
  conversation_typing_off('conversation.typing_off'),
  conversation_typing_on('conversation.typing_on'),
  conversation_status_changed('conversation.status_changed'),
  conversation_created('conversation.created'),
  conversation_updated('conversation.updated');

  const ZukkoChatEventMessageType(this.wire);

  final String wire;

  /// `null` for events this SDK does not know.
  static ZukkoChatEventMessageType? byWire(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}
