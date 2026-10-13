import 'package:dio/dio.dart';

import '../../../core/chatwoot_client_exception.dart';
import '../../models/chatwoot_contact.dart';
import '../../models/chatwoot_conversation.dart';
import '../../models/chatwoot_user.dart';
import 'api_call.dart';
import 'chatwoot_paths.dart';

/// Service for handling chatwoot user authentication api calls
/// See [ChatwootClientAuthServiceImpl]
abstract class ChatwootClientAuthService {
  final Dio dio;

  ChatwootClientAuthService(this.dio);

  Future<ChatwootContact> createNewContact(
    String inboxIdentifier,
    ChatwootUser? user,
  );

  Future<ChatwootConversation> createNewConversation(
    String inboxIdentifier,
    String contactIdentifier,
  );
}

/// Default Implementation for [ChatwootClientAuthService]
class ChatwootClientAuthServiceImpl extends ChatwootClientAuthService {
  ChatwootClientAuthServiceImpl({required Dio dio}) : super(dio);

  ///Creates new contact for inbox with [inboxIdentifier] and passes [user] body to be linked to created contact
  @override
  Future<ChatwootContact> createNewContact(
    String inboxIdentifier,
    ChatwootUser? user,
  ) => apiCall(
    ChatwootClientExceptionType.CREATE_CONTACT_FAILED,
    () => dio.post(
      ChatwootPaths.contacts(Uri.encodeComponent(inboxIdentifier)),
      data: user?.toJson(),
    ),
    (data) => ChatwootContact.fromJson(data as Map<String, dynamic>),
  );

  ///Creates a new conversation for inbox with [inboxIdentifier] and contact with source id [contactIdentifier]
  @override
  Future<ChatwootConversation> createNewConversation(
    String inboxIdentifier,
    String contactIdentifier,
  ) => apiCall(
    ChatwootClientExceptionType.CREATE_CONVERSATION_FAILED,
    () => dio.post(
      ChatwootPaths.conversations(
        Uri.encodeComponent(inboxIdentifier),
        Uri.encodeComponent(contactIdentifier),
      ),
    ),
    (data) => ChatwootConversation.fromJson(data as Map<String, dynamic>),
  );
}
