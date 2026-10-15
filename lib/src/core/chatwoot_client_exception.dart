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
  GET_MESSAGES_FAILED,
  GET_CONVERSATION_FAILED,
  UPDATE_CONTACT_FAILED,

  /// The server did not accept the realtime subscription (bad or stale token).
  SOCKET_SUBSCRIPTION_REJECTED,

  /// Local storage could not be opened or is in an unusable state (e.g. a
  /// foreign Hive adapter on the SDK's type ids). The client keeps working
  /// without persistence.
  STORAGE_FAILED,

  /// The server closed the realtime connection and asked not to reconnect.
  SOCKET_DISCONNECTED,

  /// The widget session could not be kept alive (the server keeps rejecting the
  /// token, or the widget is unavailable). Recovery is rate limited.
  SESSION_EXPIRED,

  /// The server rejected the user's `identifierHash` (HMAC). The client fails
  /// closed: no anonymous fallback, no realtime connection.
  INVALID_IDENTIFIER_HASH,

  /// `set_user` failed (5xx, timeout, 404, 422 ...) for a user with an
  /// identifier. Not terminal: the session is not usable (no sends, no
  /// realtime, never an anonymous fallback) and the next start retries it.
  /// For a user without an identifier it is only a warning.
  IDENTIFY_FAILED,

  /// Warning: `user.identifier` was given without `identifierHash`. The
  /// session continues, but the identity is unverified; enable "Enforce
  /// identity validation" on the inbox.
  IDENTITY_NOT_VERIFIED,

  /// `POST /config` failed or returned an unusable body.
  GET_CONFIG_FAILED,
}
