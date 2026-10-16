/// Actions the client can perform on the ActionCable channel.
///
/// {@category FlutterClientSdk}
enum ZukkoChatActionType {
  updatePresence('update_presence');

  const ZukkoChatActionType(this.wire);

  /// Name of the action on the wire.
  final String wire;
}
