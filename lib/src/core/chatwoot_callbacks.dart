import '../data/models/chatwoot_message.dart';
import '../data/remote/realtime/chatwoot_socket.dart';
import 'chatwoot_client_exception.dart';

///Chatwoot callback are specified for each created client instance. Methods are triggered
///when a method satisfying their respective conditions occur.
///
///
/// {@category FlutterClientSdk}
class ChatwootCallbacks {
  ///Triggered when a welcome event/message is received after connecting to
  ///the chatwoot websocket.
  final void Function()? onWelcome;

  ///Triggered when a ping event/message is received after connecting to
  ///the chatwoot websocket.
  final void Function()? onPing;

  ///Triggered when a subscription confirmation event/message is received after connecting to
  ///the chatwoot websocket.
  final void Function()? onConfirmedSubscription;

  ///Triggered when a conversation typing on event/message (conversation typing on)
  ///is received after connecting to the chatwoot websocket.
  final void Function()? onConversationStartedTyping;

  ///Triggered when a presence update event/message (presence update)
  ///is received after connecting to the chatwoot websocket and conversation is online.
  final void Function()? onConversationIsOnline;

  ///Triggered when a presence update event/message (presence update)
  ///is received after connecting to the chatwoot websocket and conversation is offline.
  final void Function()? onConversationIsOffline;

  ///Triggered when a conversation typing off event/message (conversation typing off)
  ///is received after connecting to the chatwoot websocket.
  final void Function()? onConversationStoppedTyping;

  ///Triggered when a message created event/message (message created)
  ///is received and message doesn't belong to current user after connecting to the chatwoot websocket.
  final void Function(ChatwootMessage)? onMessageReceived;

  ///Triggered when a message created event/message (message updated)
  ///is received after connecting to the chatwoot websocket.
  final void Function(ChatwootMessage)? onMessageUpdated;

  final void Function(ChatwootMessage, String)? onMessageSent;

  ///Triggered when a message created event/message (message created)
  ///is received and message belongs to current user after connecting to the chatwoot websocket.
  final void Function(ChatwootMessage, String)? onMessageDelivered;

  ///Triggered when a conversation's messages persisted on device are successfully retrieved
  final void Function(List<ChatwootMessage>)? onPersistedMessagesRetrieved;

  ///Triggered when a conversation's messages is successfully retrieved from remote server
  final void Function(List<ChatwootMessage>)? onMessagesRetrieved;

  ///Triggered when an agent resolves the current conversation
  final void Function()? onConversationResolved;

  /// Triggered whenever the realtime connection changes state (connecting,
  /// subscribed, reconnecting after a drop, ...). Use it to show an offline
  /// banner. Messages missed while disconnected are refetched automatically
  /// after the connection is back.
  final void Function(ChatwootConnectionState)? onConnectionStateChanged;

  /// Triggered when any error occurs in chatwoot client's operations with the error
  ///
  /// See [ChatwootClientExceptionType] for the various types of exceptions that can be triggered
  final void Function(ChatwootClientException)? onError;

  ChatwootCallbacks({
    this.onWelcome,
    this.onPing,
    this.onConfirmedSubscription,
    this.onMessageReceived,
    this.onMessageSent,
    this.onMessageDelivered,
    this.onMessageUpdated,
    this.onPersistedMessagesRetrieved,
    this.onMessagesRetrieved,
    this.onConversationStartedTyping,
    this.onConversationStoppedTyping,
    this.onConversationIsOnline,
    this.onConversationIsOffline,
    this.onConversationResolved,
    this.onConnectionStateChanged,
    this.onError,
  });
}
