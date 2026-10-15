/// Where the realtime connection currently is.
///
/// {@category FlutterClientSdk}
enum ZukkoChatConnectionState {
  /// Not started yet.
  idle,

  /// Opening the websocket, waiting for the server's welcome.
  connecting,

  /// Websocket is open, subscription not confirmed yet.
  connected,

  /// Subscribed to the contact's channel: events flow.
  subscribed,

  /// The connection was lost, a new attempt is scheduled.
  backoff,

  /// Disposed, or stopped for good (rejected subscription, server said not to
  /// reconnect). Starts again on the next connect.
  closed,
}
