// Imports ONLY the public barrel: proves the types that appear in public
// signatures are all reachable by SDK consumers.
import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('types used in public signatures are exported', () {
    // ChatwootClient.sendAction(ChatwootActionType)
    const ChatwootActionType action = ChatwootActionType.update_presence;
    // ChatwootMessage.sender
    final sender = ChatwootEventMessageUser(name: 'agent');
    final message = ChatwootMessage(
      id: 1,
      content: 'x',
      messageType: 1,
      contentType: null,
      contentAttributes: null,
      createdAt: '2024-01-01',
      conversationId: null,
      attachments: null,
      sender: sender,
    );
    // widgets take these
    const l10n = ChatwootL10n();
    const ChatwootChatTheme? theme = null; // type must be reachable

    expect(action.name, 'update_presence');
    expect(message.sender?.name, 'agent');
    expect(l10n, isNotNull);
    expect(theme, isNull);
  });

  test('the connection state callback receives states the app can match', () {
    final states = <ChatwootConnectionState>[];
    final callbacks = ChatwootCallbacks(onConnectionStateChanged: states.add);

    callbacks.onConnectionStateChanged!(ChatwootConnectionState.backoff);

    expect(states, [ChatwootConnectionState.backoff]);
    expect(
      ChatwootConnectionState.values,
      contains(ChatwootConnectionState.subscribed),
    );
  });

  test('the only public action is the presence heartbeat (no "subscribe")', () {
    expect(ChatwootActionType.values.map((a) => a.name), ['update_presence']);
  });

  test('the instance key separates users, hashes and inboxes', () {
    String key({String? user, String? hash, String inbox = 'i'}) =>
        ChatwootClient.getClientInstanceKey(
          baseUrl: 'https://b',
          websiteToken: inbox,
          userIdentifier: user,
          identifierHash: hash,
        );

    final keys = {
      key(),
      key(user: 'u'),
      key(user: 'u', hash: 'h'),
      key(user: 'u', hash: 'h2'),
      key(user: 'u', inbox: 'other'),
    };

    expect(keys, hasLength(5));
  });

  test('create() refuses an insecure base url (SEC4)', () async {
    await expectLater(
      ChatwootClient.create(
        baseUrl: 'http://chat.example.com',
        websiteToken: 'i',
        enablePersistence: false,
      ),
      throwsArgumentError,
    );
  });
}
