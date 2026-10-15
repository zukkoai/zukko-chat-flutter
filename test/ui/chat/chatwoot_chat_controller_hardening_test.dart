import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/ui/chat/chatwoot_chat_controller.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fakes.dart';

const _options = ChatwootChatOptions(
  baseUrl: 'https://x.test',
  websiteToken: 'in',
);

void main() {
  late FakeFactory factory;
  late FakeClient client;
  late ChatwootChatController controller;
  late SpyChat chat;

  setUp(() {
    factory = FakeFactory();
    client = FakeClient();
    chat = SpyChat();
    controller = ChatwootChatController(
      _options,
      clientFactory: factory.call,
      chat: chat,
    );
  });

  tearDown(() => controller.dispose());

  Future<String> sendOne() async {
    factory.completer.complete(client);
    await pumpEventQueue();
    controller.send('hi');
    await pumpEventQueue();
    return client.sent.single.echoId;
  }

  MessageStatus? status() => (chat.messages.single as TextMessage).status;

  group('a failed send marks its bubble whatever the error type (1)', () {
    for (final type in [
      ChatwootClientExceptionType.INVALID_IDENTIFIER_HASH,
      ChatwootClientExceptionType.SESSION_EXPIRED,
      ChatwootClientExceptionType.IDENTIFY_FAILED,
      ChatwootClientExceptionType.GET_CONFIG_FAILED,
      ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
    ]) {
      test(type.name, () async {
        final echoId = await sendOne();
        expect(status(), isNot(MessageStatus.error));

        factory.callbacks!.onError!(
          ChatwootClientException('x', type, data: echoId),
        );

        expect(status(), MessageStatus.error);
      });
    }

    test('an error that carries something else leaves bubbles alone', () async {
      await sendOne();

      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.SESSION_EXPIRED,
          data: 'not-an-echo-id',
        ),
      );

      expect(status(), isNot(MessageStatus.error));
    });
  });

  group('banner state', () {
    test('IDENTIFY_FAILED shows the (retryable) error state', () async {
      factory.completer.complete(client);
      await pumpEventQueue();

      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.IDENTIFY_FAILED,
        ),
      );

      expect(
        controller.error?.type,
        ChatwootClientExceptionType.IDENTIFY_FAILED,
      );
    });

    test('IDENTITY_NOT_VERIFIED is a warning, not an error state', () async {
      factory.completer.complete(client);
      await pumpEventQueue();

      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.IDENTITY_NOT_VERIFIED,
        ),
      );

      expect(controller.error, isNull);
    });
  });

  test('coming back to the foreground resumes realtime', () async {
    factory.completer.complete(client);
    await pumpEventQueue();

    controller.visible = false;
    controller.visible = true;

    expect(client.resumes, 1);
  });
}
