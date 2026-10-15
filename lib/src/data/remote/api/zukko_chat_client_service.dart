import 'package:dio/dio.dart';

import '../../../core/zukko_chat_client_exception.dart';
import '../../../core/zukko_chat_upload.dart';
import '../../../core/zukko_chat_upload_policy.dart';
import '../../models/zukko_chat_conversation.dart';
import '../../models/zukko_chat_message.dart';
import 'api_call.dart';
import 'zukko_chat_paths.dart';
import 'requests/zukko_chat_new_message_request.dart';
import 'widget_auth_interceptor.dart';
import 'message_body.dart';

/// Service for handling the Widget API calls of the current session.
/// See [ZukkoChatClientServiceImpl]
abstract interface class ZukkoChatClientService {
  /// One page of messages, oldest first: the latest 20 without a cursor, 20
  /// older than id [before], or up to 100 newer than id [after].
  Future<List<ZukkoChatMessage>> getMessages({int? before, int? after});

  /// The contact's current conversation, or null when it has none yet.
  Future<ZukkoChatConversation?> getConversation();

  /// Sends [request], as multipart when [attachments] is not empty. Creates
  /// the conversation if the contact has none.
  Future<ZukkoChatMessage> createMessage(
    ZukkoChatNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  });

  /// Tells agents the contact started or stopped typing. Throws
  /// `UPDATE_CONTACT_FAILED` (also used for [updateLastSeen]: it covers the
  /// contact's conversation state).
  Future<void> toggleTyping(bool on);

  /// Marks the agents' messages as read.
  Future<void> updateLastSeen();
}

class ZukkoChatClientServiceImpl implements ZukkoChatClientService {
  ZukkoChatClientServiceImpl({required this._dio});

  final Dio _dio;

  /// A 40 MB upload on a slow link outlasts the default send timeout.
  static const _uploadSendTimeout = Duration(minutes: 5);

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
          ZukkoChatPaths.messages,
          queryParameters: {'before': ?before, 'after': ?after},
        ),
        parseMessagesPage,
      );

  @override
  Future<ZukkoChatConversation?> getConversation() => apiCall(
    ZukkoChatExceptionType.GET_CONVERSATION_FAILED,
    () => _dio.get(ZukkoChatPaths.conversations),
    (data) {
      final conversation = ZukkoChatConversation.fromJson(
        data as Map<String, dynamic>,
      );
      return conversation.id > 0 ? conversation : null; // `{}`: none yet
    },
  );

  @override
  Future<ZukkoChatMessage> createMessage(
    ZukkoChatNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  }) => apiCall(ZukkoChatExceptionType.SEND_MESSAGE_FAILED, () async {
    for (final file in attachments) {
      await validateUpload(file);
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
    return _dio.post(
      ZukkoChatPaths.messages,
      data: body,
      options: attachments.isEmpty
          ? null
          : Options(sendTimeout: _uploadSendTimeout),
    );
  }, (data) => ZukkoChatMessage.fromJson(data as Map<String, dynamic>));

  @override
  Future<void> toggleTyping(bool on) => apiCall(
    ZukkoChatExceptionType.UPDATE_CONTACT_FAILED,
    () => _dio.post(
      ZukkoChatPaths.toggleTyping,
      queryParameters: {'typing_status': on ? 'on' : 'off'},
      options: _noRecover,
    ),
    (_) {},
  );

  @override
  Future<void> updateLastSeen() => apiCall(
    ZukkoChatExceptionType.UPDATE_CONTACT_FAILED,
    () => _dio.post(ZukkoChatPaths.updateLastSeen, options: _noRecover),
    (_) {},
  );
}

/// Parses the body of `GET /messages`: `{payload: [...], meta: {...}}` (a bare
/// list is accepted too). Malformed items and items without a positive id are
/// skipped.
List<ZukkoChatMessage> parseMessagesPage(Object? data) =>
    parseMessages(data is Map<String, dynamic> ? data['payload'] : data);
