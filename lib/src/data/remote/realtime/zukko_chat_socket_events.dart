import '../../../core/zukko_chat_client_exception.dart';
import '../../../core/zukko_chat_connection_state.dart';
import 'zukko_chat_event.dart';

/// What `ZukkoChatSocket.events` emits.
sealed class SocketEvent {
  const SocketEvent();
}

class SocketStateChanged extends SocketEvent {
  const SocketStateChanged(this.state);

  final ZukkoChatConnectionState state;
}

class SocketPing extends SocketEvent {
  const SocketPing();
}

class SocketMessage extends SocketEvent {
  const SocketMessage(this.message);

  final ZukkoChatEventMessage message;
}

class SocketFailure extends SocketEvent {
  const SocketFailure(this.error);

  final ZukkoChatException error;
}
