/// Actions the client can perform on the ActionCable channel.
///
/// {@category FlutterClientSdk}
enum ChatwootActionType {
  update_presence('update_presence');

  const ChatwootActionType(this.wire);

  /// Name of the action on the wire.
  final String wire;
}
