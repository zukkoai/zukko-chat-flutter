/// Actions the client can perform on the ActionCable channel.
///
/// {@category FlutterClientSdk}
enum ZukkoChatActionType {
  update_presence('update_presence');

  const ZukkoChatActionType(this.wire);

  /// Name of the action on the wire.
  final String wire;
}
