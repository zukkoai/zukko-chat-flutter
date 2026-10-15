/// The single error type the SDK reports (through
/// `ZukkoChatCallbacks.onError`, or thrown by the few calls that can throw).
///
/// {@category FlutterClientSdk}
class ZukkoChatException implements Exception {
  /// Human-readable description; never contains secrets.
  final String cause;

  /// Extra payload; for a failed send it is the message's `echoId`.
  final dynamic data;
  final ZukkoChatExceptionType type;

  /// The underlying error, when there was one (for crash reporters). It is
  /// never an object that holds request headers or tokens.
  final Object? error;

  /// Stack trace of [error], when known.
  final StackTrace? stackTrace;

  ZukkoChatException(
    this.cause,
    this.type, {
    this.data,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() => 'ZukkoChatException(${type.name}): $cause';
}

/// {@category FlutterClientSdk}
enum ZukkoChatExceptionType {
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
