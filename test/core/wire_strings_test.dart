import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_event.dart';

/// The Dart identifiers are lowerCamelCase; the strings host apps and the
/// server see must never change.
void main() {
  test('ZukkoChatExceptionType codes are byte-identical', () {
    const expected = {
      ZukkoChatExceptionType.createClientFailed: 'CREATE_CLIENT_FAILED',
      ZukkoChatExceptionType.sendMessageFailed: 'SEND_MESSAGE_FAILED',
      ZukkoChatExceptionType.getMessagesFailed: 'GET_MESSAGES_FAILED',
      ZukkoChatExceptionType.getConversationFailed: 'GET_CONVERSATION_FAILED',
      ZukkoChatExceptionType.updateContactFailed: 'UPDATE_CONTACT_FAILED',
      ZukkoChatExceptionType.socketSubscriptionRejected:
          'SOCKET_SUBSCRIPTION_REJECTED',
      ZukkoChatExceptionType.storageFailed: 'STORAGE_FAILED',
      ZukkoChatExceptionType.socketDisconnected: 'SOCKET_DISCONNECTED',
      ZukkoChatExceptionType.sessionExpired: 'SESSION_EXPIRED',
      ZukkoChatExceptionType.invalidIdentifierHash: 'INVALID_IDENTIFIER_HASH',
      ZukkoChatExceptionType.identifyFailed: 'IDENTIFY_FAILED',
      ZukkoChatExceptionType.identityNotVerified: 'IDENTITY_NOT_VERIFIED',
      ZukkoChatExceptionType.getConfigFailed: 'GET_CONFIG_FAILED',
    };
    expect(expected.length, ZukkoChatExceptionType.values.length);
    expected.forEach((type, wire) => expect(type.wire, wire));
    expect(
      ZukkoChatException('x', ZukkoChatExceptionType.storageFailed).toString(),
      'ZukkoChatException(STORAGE_FAILED): x',
    );
  });

  test('ZukkoChatActionType wire name is unchanged', () {
    expect(ZukkoChatActionType.updatePresence.wire, 'update_presence');
  });

  test('server event names parse to the same values', () {
    const expected = {
      'presence.update': ZukkoChatEventMessageType.presenceUpdate,
      'message.created': ZukkoChatEventMessageType.messageCreated,
      'message.updated': ZukkoChatEventMessageType.messageUpdated,
      'conversation.typing_off':
          ZukkoChatEventMessageType.conversationTypingOff,
      'conversation.typing_on': ZukkoChatEventMessageType.conversationTypingOn,
      'conversation.status_changed':
          ZukkoChatEventMessageType.conversationStatusChanged,
      'conversation.created': ZukkoChatEventMessageType.conversationCreated,
      'conversation.updated': ZukkoChatEventMessageType.conversationUpdated,
    };
    expect(expected.length, ZukkoChatEventMessageType.values.length);
    expected.forEach((wire, type) {
      expect(ZukkoChatEventMessageType.byWire(wire), type);
      expect(type.wire, wire);
    });
  });
}
