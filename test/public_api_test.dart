// Imports ONLY the public barrel: proves the types that appear in public
// signatures are all reachable by SDK consumers.
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('types used in public signatures are exported', () {
    // ZukkoChatClient.sendAction(ZukkoChatActionType)
    const ZukkoChatActionType action = ZukkoChatActionType.update_presence;
    // ZukkoChatMessage.sender
    final sender = ZukkoChatEventMessageUser(name: 'agent');
    final message = ZukkoChatMessage(
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
    const l10n = ZukkoChatL10n();
    const ZukkoChatTheme? theme = null; // type must be reachable

    expect(action.name, 'update_presence');
    expect(message.sender?.name, 'agent');
    expect(l10n, isNotNull);
    expect(theme, isNull);
  });

  test('the config and conversation types of the public API are exported', () {
    // ZukkoChatClient.config and ZukkoChatCallbacks.onConversationUpdated
    const ZukkoChatConfig? config = null;
    final updates = <ZukkoChatConversation>[];
    final callbacks = ZukkoChatCallbacks(onConversationUpdated: updates.add);

    callbacks.onConversationUpdated!(
      const ZukkoChatConversation(id: 1, inboxId: 2, status: 'resolved'),
    );

    expect(config, isNull);
    expect(updates.single.isResolved, isTrue);
  });

  test('the connection state callback receives states the app can match', () {
    final states = <ZukkoChatConnectionState>[];
    final callbacks = ZukkoChatCallbacks(onConnectionStateChanged: states.add);

    callbacks.onConnectionStateChanged!(ZukkoChatConnectionState.backoff);

    expect(states, [ZukkoChatConnectionState.backoff]);
    expect(
      ZukkoChatConnectionState.values,
      contains(ZukkoChatConnectionState.subscribed),
    );
  });

  test('the only public action is the presence heartbeat (no "subscribe")', () {
    expect(ZukkoChatActionType.values.map((a) => a.name), ['update_presence']);
  });

  test('the instance key separates users, hashes and inboxes', () {
    String key({String? user, String? hash, String inbox = 'i'}) =>
        ZukkoChatClient.getClientInstanceKey(
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
      ZukkoChatClient.create(
        baseUrl: 'http://chat.example.com',
        websiteToken: 'i',
        enablePersistence: false,
      ),
      throwsArgumentError,
    );
  });
}
