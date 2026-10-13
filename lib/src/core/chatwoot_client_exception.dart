/// {@category FlutterClientSdk}
class ChatwootClientException implements Exception {
  final String cause;
  final dynamic data;
  final ChatwootClientExceptionType type;

  ChatwootClientException(this.cause, this.type, {this.data});

  @override
  String toString() => 'ChatwootClientException(${type.name}): $cause';
}

/// {@category FlutterClientSdk}
enum ChatwootClientExceptionType {
  CREATE_CLIENT_FAILED,
  SEND_MESSAGE_FAILED,
  CREATE_CONTACT_FAILED,
  CREATE_CONVERSATION_FAILED,
  GET_MESSAGES_FAILED,
  GET_CONTACT_FAILED,
  GET_CONVERSATION_FAILED,
  UPDATE_CONTACT_FAILED,
  UPDATE_MESSAGE_FAILED,

  /// The server did not accept the realtime subscription (bad or stale token).
  SOCKET_SUBSCRIPTION_REJECTED,

  /// Local storage could not be opened or is in an unusable state (e.g. a
  /// foreign Hive adapter on the SDK's type ids). The client keeps working
  /// without persistence.
  STORAGE_FAILED,

  /// The server closed the realtime connection and asked not to reconnect.
  SOCKET_DISCONNECTED,
}
