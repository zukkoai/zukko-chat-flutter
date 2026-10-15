import '../data/models/zukko_chat_conversation.dart';
import '../data/models/zukko_chat_message.dart';
import 'zukko_chat_client_exception.dart';
import 'zukko_chat_connection_state.dart';

/// The app's hooks into a client: each callback is optional and is triggered
/// when what it names happens. They are given per client instance, and a
/// callback that throws never breaks the SDK.
///
/// {@category FlutterClientSdk}
class ZukkoChatCallbacks {
  ///Triggered when a welcome event/message is received after connecting to
  ///the Zukko Chat websocket.
  final void Function()? onWelcome;

  ///Triggered when a ping event/message is received after connecting to
  ///the Zukko Chat websocket.
  final void Function()? onPing;

  ///Triggered when a subscription confirmation event/message is received after connecting to
  ///the Zukko Chat websocket.
  final void Function()? onConfirmedSubscription;

  ///Triggered when a conversation typing on event/message (conversation typing on)
  ///is received after connecting to the Zukko Chat websocket.
  final void Function()? onConversationStartedTyping;

  ///Triggered when a presence update event/message (presence update)
  ///is received after connecting to the Zukko Chat websocket and conversation is online.
  final void Function()? onConversationIsOnline;

  ///Triggered when a presence update event/message (presence update)
  ///is received after connecting to the Zukko Chat websocket and conversation is offline.
  final void Function()? onConversationIsOffline;

  ///Triggered when a conversation typing off event/message (conversation typing off)
  ///is received after connecting to the Zukko Chat websocket.
  final void Function()? onConversationStoppedTyping;

  ///Triggered when a message created event/message (message created)
  ///is received and message doesn't belong to current user after connecting to the Zukko Chat websocket.
  final void Function(ZukkoChatMessage)? onMessageReceived;

  ///Triggered when a message created event/message (message updated)
  ///is received after connecting to the Zukko Chat websocket.
  final void Function(ZukkoChatMessage)? onMessageUpdated;

  /// Triggered when a message sent with `ZukkoChatClient.sendMessage` was
  /// accepted by the server: the created message and the `echoId` you gave it.
  final void Function(ZukkoChatMessage, String)? onMessageSent;

  ///Triggered when a message created event/message (message created)
  ///is received and message belongs to current user after connecting to the Zukko Chat websocket.
  final void Function(ZukkoChatMessage, String)? onMessageDelivered;

  ///Triggered when a conversation's messages persisted on device are successfully retrieved
  final void Function(List<ZukkoChatMessage>)? onPersistedMessagesRetrieved;

  ///Triggered when a conversation's messages is successfully retrieved from remote server
  final void Function(List<ZukkoChatMessage>)? onMessagesRetrieved;

  ///Triggered when an agent resolves the current conversation
  final void Function()? onConversationResolved;

  /// Triggered over the realtime connection when the contact's conversation is
  /// created or changes (for example an agent resolves it): carries the
  /// current [ZukkoChatConversation] (its ids and `status`). It also fires
  /// together with [onConversationResolved] when the status becomes `resolved`.
  /// Not triggered by the initial fetch at start, only by later server events
  /// of the contact's own inbox.
  final void Function(ZukkoChatConversation)? onConversationUpdated;

  /// Triggered when the visitor's session was replaced (the server no longer
  /// knew the old one, so this is a new contact): messages shown so far belong
  /// to someone else and must be dropped; the latest page is fetched right after.
  final void Function()? onSessionReset;

  /// Triggered whenever the realtime connection changes state (connecting,
  /// subscribed, reconnecting after a drop, ...). Use it to show an offline
  /// banner. Messages missed while disconnected are refetched automatically
  /// after the connection is back.
  final void Function(ZukkoChatConnectionState)? onConnectionStateChanged;

  /// Triggered when any error occurs in Zukko Chat client's operations with the error
  ///
  /// See [ZukkoChatExceptionType] for the various types of exceptions that can be triggered
  final void Function(ZukkoChatException)? onError;

  ZukkoChatCallbacks({
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
    this.onConversationUpdated,
    this.onSessionReset,
    this.onConnectionStateChanged,
    this.onError,
  });
}
