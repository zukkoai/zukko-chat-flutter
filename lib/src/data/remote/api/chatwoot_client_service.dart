import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';
import '../../../core/chatwoot_upload.dart';
import '../../models/chatwoot_contact.dart';
import '../../models/chatwoot_conversation.dart';
import '../../models/chatwoot_message.dart';
import '../../../shared/json_converters.dart';
import 'api_call.dart';
import 'chatwoot_client_api_interceptor.dart';
import 'chatwoot_paths.dart';
import 'requests/chatwoot_new_message_request.dart';

/// Service for handling chatwoot api calls
/// See [ChatwootClientServiceImpl]
abstract class ChatwootClientService {
  final Dio _dio;

  ChatwootClientService(this._dio);

  Future<ChatwootContact> getContact();

  Future<List<ChatwootConversation>> getConversations();

  Future<ChatwootMessage> createMessage(ChatwootNewMessageRequest request);

  /// Sends [request] with [attachments] as one multipart message.
  Future<ChatwootMessage> createMessageWithAttachments(
    ChatwootNewMessageRequest request,
    List<ChatwootUpload> attachments,
  );

  Future<List<ChatwootMessage>> getAllMessages();
}

// Paths contain placeholders the interceptor fills in per request.
const _inbox = ChatwootClientApiInterceptor.inboxPlaceholder;
const _contact = ChatwootClientApiInterceptor.contactPlaceholder;
const _conversation = ChatwootClientApiInterceptor.conversationPlaceholder;

final _contactPath = ChatwootPaths.contact(_inbox, _contact);
final _conversationsPath = ChatwootPaths.conversations(_inbox, _contact);
final _messagesPath = ChatwootPaths.messages(_inbox, _contact, _conversation);

class ChatwootClientServiceImpl extends ChatwootClientService {
  ChatwootClientServiceImpl({required Dio dio}) : super(dio);

  ///Sends message to chatwoot inbox
  @override
  Future<ChatwootMessage> createMessage(ChatwootNewMessageRequest request) =>
      apiCall(
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
        () => _dio.post(_messagesPath, data: request.toJson()),
        (data) => ChatwootMessage.fromJson(data as Map<String, dynamic>),
      );

  /// Multipart `content` (when not empty), `echo_id` and one
  /// `attachments[]` part per file; the content type comes from the name.
  @override
  Future<ChatwootMessage> createMessageWithAttachments(
    ChatwootNewMessageRequest request,
    List<ChatwootUpload> attachments,
  ) => apiCall(ChatwootClientExceptionType.SEND_MESSAGE_FAILED, () async {
    final form = FormData();
    if (request.content.isNotEmpty) {
      form.fields.add(MapEntry('content', request.content));
    }
    form.fields.add(MapEntry('echo_id', request.echoId));
    for (final file in attachments) {
      form.files.add(MapEntry('attachments[]', await _part(file)));
    }
    return _dio.post(_messagesPath, data: form);
  }, (data) => ChatwootMessage.fromJson(data as Map<String, dynamic>));

  static Future<MultipartFile> _part(ChatwootUpload file) {
    final bytes = file.bytes;
    if (bytes != null) {
      return Future.value(MultipartFile.fromBytes(bytes, filename: file.name));
    }
    return MultipartFile.fromFile(file.path!, filename: file.name);
  }

  ///Gets all messages of current chatwoot client instance's conversation
  @override
  Future<List<ChatwootMessage>> getAllMessages() => apiCall(
    ChatwootClientExceptionType.GET_MESSAGES_FAILED,
    () => _dio.get(_messagesPath),
    (data) => parseMessages(data),
  );

  ///Gets contact of current chatwoot client instance
  @override
  Future<ChatwootContact> getContact() => apiCall(
    ChatwootClientExceptionType.GET_CONTACT_FAILED,
    () => _dio.get(_contactPath),
    (data) => ChatwootContact.fromJson(data as Map<String, dynamic>),
  );

  ///Gets all conversation of current chatwoot client instance
  @override
  Future<List<ChatwootConversation>> getConversations() => apiCall(
    ChatwootClientExceptionType.GET_CONVERSATION_FAILED,
    () => _dio.get(_conversationsPath),
    (data) => [
      for (final c in parseList(data, ChatwootConversation.fromJson))
        if (c.id > 0) c,
    ],
  );
}
