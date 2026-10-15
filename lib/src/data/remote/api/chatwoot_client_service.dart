import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';
import '../../../core/chatwoot_upload.dart';
import '../../models/chatwoot_conversation.dart';
import '../../models/chatwoot_message.dart';
import 'api_call.dart';
import 'chatwoot_paths.dart';
import 'requests/chatwoot_new_message_request.dart';
import 'widget_auth_interceptor.dart';
import 'widget_message_form.dart';

/// Service for handling the Widget API calls of the current session.
/// See [ChatwootClientServiceImpl]
abstract class ChatwootClientService {
  final Dio _dio;

  ChatwootClientService(this._dio);

  /// One page of messages, oldest first: the latest 20 without a cursor, 20
  /// older than id [before], or up to 100 newer than id [after].
  Future<List<ZukkoChatMessage>> getMessages({int? before, int? after});

  /// The contact's current conversation, or null when it has none yet.
  Future<ZukkoChatConversation?> getConversation();

  /// Sends [request], as multipart when [attachments] is not empty. Creates
  /// the conversation if the contact has none.
  Future<ZukkoChatMessage> createMessage(
    ChatwootNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  });

  /// Tells agents the contact started or stopped typing.
  Future<void> toggleTyping(bool on);

  /// Marks the agents' messages as read.
  Future<void> updateLastSeen();
}

class ChatwootClientServiceImpl extends ChatwootClientService {
  ChatwootClientServiceImpl({required Dio dio}) : super(dio);

  /// Fire-and-forget calls: a 404 (no conversation yet) must not start a
  /// session recovery.
  static final _noRecover = Options(
    extra: {WidgetAuthInterceptor.noRecover: true},
  );

  @override
  Future<List<ZukkoChatMessage>> getMessages({int? before, int? after}) =>
      apiCall(
        ZukkoChatExceptionType.GET_MESSAGES_FAILED,
        () => _dio.get(
          ChatwootPaths.messages,
          queryParameters: {'before': ?before, 'after': ?after},
        ),
        parseMessagesPage,
      );

  @override
  Future<ZukkoChatConversation?> getConversation() => apiCall(
    ZukkoChatExceptionType.GET_CONVERSATION_FAILED,
    () => _dio.get(ChatwootPaths.conversations),
    (data) {
      final conversation = ZukkoChatConversation.fromJson(
        data as Map<String, dynamic>,
      );
      return conversation.id > 0 ? conversation : null; // `{}`: none yet
    },
  );

  @override
  Future<ZukkoChatMessage> createMessage(
    ChatwootNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  }) => apiCall(ZukkoChatExceptionType.SEND_MESSAGE_FAILED, () async {
    for (final file in attachments) {
      await validateUploadFile(file);
    }
    final Object body = attachments.isEmpty
        ? buildMessageJson(
            content: request.content,
            echoId: request.echoId,
            replyTo: request.replyTo,
          )
        : await buildMessageForm(
            content: request.content,
            echoId: request.echoId,
            files: attachments,
            replyTo: request.replyTo,
          );
    return _dio.post(ChatwootPaths.messages, data: body);
  }, (data) => ZukkoChatMessage.fromJson(data as Map<String, dynamic>));

  @override
  Future<void> toggleTyping(bool on) => apiCall(
    ZukkoChatExceptionType.UPDATE_CONTACT_FAILED,
    () => _dio.post(
      ChatwootPaths.toggleTyping,
      queryParameters: {'typing_status': on ? 'on' : 'off'},
      options: _noRecover,
    ),
    (_) {},
  );

  @override
  Future<void> updateLastSeen() => apiCall(
    ZukkoChatExceptionType.UPDATE_CONTACT_FAILED,
    () => _dio.post(ChatwootPaths.updateLastSeen, options: _noRecover),
    (_) {},
  );
}
