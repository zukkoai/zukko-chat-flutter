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
  String toString() => 'ZukkoChatException(${type.wire}): $cause';
}

/// {@category FlutterClientSdk}
enum ZukkoChatExceptionType {
  createClientFailed('CREATE_CLIENT_FAILED'),
  sendMessageFailed('SEND_MESSAGE_FAILED'),
  getMessagesFailed('GET_MESSAGES_FAILED'),
  getConversationFailed('GET_CONVERSATION_FAILED'),
  updateContactFailed('UPDATE_CONTACT_FAILED'),

  /// The server did not accept the realtime subscription (bad or stale token).
  socketSubscriptionRejected('SOCKET_SUBSCRIPTION_REJECTED'),

  /// Local storage could not be opened or is in an unusable state (e.g. a
  /// foreign Hive adapter on the SDK's type ids). The client keeps working
  /// without persistence.
  storageFailed('STORAGE_FAILED'),

  /// The server closed the realtime connection and asked not to reconnect.
  socketDisconnected('SOCKET_DISCONNECTED'),

  /// The widget session could not be kept alive (the server keeps rejecting the
  /// token, or the widget is unavailable). Recovery is rate limited.
  sessionExpired('SESSION_EXPIRED'),

  /// The server rejected the user's `identifierHash` (HMAC). The client fails
  /// closed: no anonymous fallback, no realtime connection.
  invalidIdentifierHash('INVALID_IDENTIFIER_HASH'),

  /// `set_user` failed (5xx, timeout, 404, 422 ...) for a user with an
  /// identifier. Not terminal: the session is not usable (no sends, no
  /// realtime, never an anonymous fallback) and the next start retries it.
  /// For a user without an identifier it is only a warning.
  identifyFailed('IDENTIFY_FAILED'),

  /// No longer emitted by the SDK (an identifier without a hash is accepted
  /// silently while the inbox does not enforce identity validation). Kept so
  /// existing code that switches on it still compiles.
  identityNotVerified('IDENTITY_NOT_VERIFIED'),

  /// `POST /config` failed or returned an unusable body.
  getConfigFailed('GET_CONFIG_FAILED');

  const ZukkoChatExceptionType(this.wire);

  /// Stable string code of the error; unchanged across releases.
  final String wire;
}
