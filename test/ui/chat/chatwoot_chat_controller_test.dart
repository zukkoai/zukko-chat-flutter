import 'dart:async';
import 'dart:typed_data';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/ui/chat/chatwoot_chat_controller.dart';
import 'package:chatwoot_sdk/src/ui/chat/components/gallery_message.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_fakes.dart';

const _options = ChatwootChatOptions(
  baseUrl: 'https://x.test',
  inboxIdentifier: 'in',
);

void main() {
  late FakeFactory factory;
  late FakeClient client;
  late List<ChatwootClientException> errors;
  late SpyChat chat;
  late ChatwootChatController controller;

  ChatwootChatController make({ChatwootCallbacks? callbacks}) {
    chat = SpyChat();
    return ChatwootChatController(
      _options,
      callbacks: callbacks ?? ChatwootCallbacks(onError: errors.add),
      clientFactory: factory.call,
      chat: chat,
    );
  }

  Future<void> ready() async {
    factory.completer.complete(client);
    await pumpEventQueue();
  }

  List<TextMessage> texts() => chat.messages.cast<TextMessage>();

  setUp(() {
    factory = FakeFactory();
    client = FakeClient();
    errors = [];
    controller = make();
  });

  tearDown(() => controller.dispose());

  group('lifecycle (U3)', () {
    test(
      'a client created after dispose is disposed, nothing is reported',
      () async {
        controller.dispose();
        await ready();

        expect(client.disposed, isTrue);
        expect(client.loads, 0);
        expect(errors, isEmpty);
      },
    );

    test('dispose disposes the live client once ready', () async {
      await ready();
      expect(client.loads, 1);

      controller.dispose();
      expect(client.disposed, isTrue);
    });

    test('factory failure is reported once as CREATE_CLIENT_FAILED', () async {
      factory.completer.completeError(StateError('boom'));
      await pumpEventQueue();

      expect(
        errors.single.type,
        ChatwootClientExceptionType.CREATE_CLIENT_FAILED,
      );
      expect(controller.error, isNotNull);
    });

    test(
      'failure: queued messages turn to error, queue cleared (F6)',
      () async {
        controller.send('queued');
        factory.completer.completeError(StateError('boom'));
        await pumpEventQueue();

        expect(texts().single.status, MessageStatus.error);
        // a later send does not wait forever either
        controller.send('later');
        expect(texts().last.status, MessageStatus.error);
      },
    );

    test(
      'retry after a failed start flushes nothing stale and recovers (F6)',
      () async {
        factory.completer.completeError(StateError('boom'));
        await pumpEventQueue();
        expect(controller.error, isNotNull);

        factory.completer = Completer<ChatwootClient>();
        controller.retry();
        expect(controller.error, isNull);
        await ready();

        expect(factory.calls, 2);
        expect(controller.isReady, isTrue);
        controller.send('hi');
        expect(client.sent.single.content, 'hi');
      },
    );

    test('retry is a no-op while nothing failed', () async {
      controller.retry();
      expect(factory.calls, 1);
    });

    test('allowInsecure reaches the factory (SEC4)', () async {
      controller.dispose();
      factory = FakeFactory();
      controller = ChatwootChatController(
        const ChatwootChatOptions(
          baseUrl: 'http://x.test',
          inboxIdentifier: 'in',
          allowInsecure: true,
        ),
        clientFactory: factory.call,
      );

      expect(factory.allowInsecure, isTrue);
    });

    test('callbacks can be swapped while running (F5)', () async {
      var a = 0, b = 0;
      controller.callbacks = ChatwootCallbacks(onMessageReceived: (_) => a++);
      await ready();
      controller.callbacks = ChatwootCallbacks(onMessageReceived: (_) => b++);
      factory.callbacks!.onMessageReceived!(msg(1));

      expect([a, b], [0, 1]);
    });

    test('factory failure after dispose is silent', () async {
      controller.dispose();
      factory.completer.completeError(StateError('boom'));
      await pumpEventQueue();

      expect(errors, isEmpty);
    });

    test('events after dispose are dropped', () async {
      var received = 0;
      controller.dispose();
      controller = make(
        callbacks: ChatwootCallbacks(onMessageReceived: (_) => received++),
      );
      final cb = factory.callbacks!;
      controller.dispose();

      cb.onMessageReceived!(msg(1));
      expect(received, 0);
    });
  });

  group('sending (U4)', () {
    test(
      'send before the client is ready is queued, then sent exactly once',
      () async {
        controller.send('hi');

        expect(client.sent, isEmpty);
        expect(texts().single.status, MessageStatus.sending);
        expect(controller.isReady, isFalse);

        await ready();

        expect(client.sent.single.content, 'hi');
        expect(client.sent.single.echoId, texts().single.id);
      },
    );

    test('resend before ready is queued too', () async {
      controller.send('hi');
      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
          data: texts().single.id,
        ),
      );
      expect(texts().single.status, MessageStatus.error);

      controller.resend(texts().single.id);
      expect(texts().single.status, MessageStatus.sending);
      await ready();

      // original queued entry + the retry share the echoId: one send
      expect(client.sent.map((s) => s.echoId).toSet().length, 1);
    });

    test('blank text is ignored', () async {
      controller.send('   ');
      expect(chat.messages, isEmpty);
    });

    test('a failed send is marked and can be resent', () async {
      await ready();
      controller.send('hi');
      final id = texts().single.id;
      factory.callbacks!.onError!(
        ChatwootClientException(
          'x',
          ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
          data: id,
        ),
      );

      expect(texts().single.status, MessageStatus.error);
      expect(
        errors.single.type,
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
      );

      controller.resend(id);

      expect(texts().single.status, MessageStatus.sending);
      expect(client.sent.length, 2);
      expect(client.sent.last.echoId, id);
    });

    test('a throwing sendMessage marks the bubble failed', () async {
      client.sendError = StateError('offline');
      await ready();
      controller.send('hi');
      await pumpEventQueue();

      expect(texts().single.status, MessageStatus.error);
    });
  });

  group('dedupe and ordering (U6)', () {
    setUp(() async {
      await ready();
      controller.send('hi');
    });

    String echo() => client.sent.single.echoId;

    test('server echo after the REST confirmation updates the same bubble', () {
      factory.callbacks!.onMessageSent!(msg(5, content: 'hi', type: 0), echo());
      factory.callbacks!.onMessageReceived!(msg(5, content: 'hi', type: 0));

      expect(chat.messages.length, 1);
      expect(chat.messages.single.id, echo());
    });

    test(
      'server echo BEFORE the REST confirmation does not leave a duplicate',
      () {
        factory.callbacks!.onMessageReceived!(msg(5, content: 'hi', type: 0));
        expect(chat.messages.length, 2);

        factory.callbacks!.onMessageSent!(
          msg(5, content: 'hi', type: 0),
          echo(),
        );

        expect(chat.messages.length, 1);
        expect(chat.messages.single.id, echo());
        // and a later update still lands on it
        factory.callbacks!.onMessageUpdated!(
          msg(5, content: 'edited', type: 0),
        );
        expect(texts().single.text, 'edited');
      },
    );

    test('a later full reload does not duplicate the sent message', () {
      factory.callbacks!.onMessageSent!(msg(5, content: 'hi', type: 0), echo());
      factory.callbacks!.onMessagesRetrieved!([msg(5, content: 'hi', type: 0)]);

      expect(chat.messages.length, 1);
    });

    test('delivery never downgrades to a lower status', () {
      factory.callbacks!.onMessageDelivered!(msg(5, type: 0), echo());
      factory.callbacks!.onMessageSent!(msg(5, type: 0), echo());

      expect(texts().single.status, MessageStatus.seen);
    });

    test('activity and template messages produce no bubble', () {
      factory.callbacks!.onMessagesRetrieved!([
        msg(10, type: 2),
        msg(11, type: 3),
      ]);
      factory.callbacks!.onMessageReceived!(msg(12, type: 2));

      expect(chat.messages.length, 1); // only the local "hi"
    });

    test('an older message arriving late is placed by time, not appended', () {
      factory.callbacks!.onMessageReceived!(
        msg(1, content: 'old', createdAt: '2000-01-01 00:00:00'),
      );

      expect(texts().first.text, 'old');
      expect(texts().last.text, 'hi');
    });

    test('incoming agent messages and own messages get different authors', () {
      factory.callbacks!.onMessageReceived!(msg(20, type: 1));
      factory.callbacks!.onMessageReceived!(msg(21, type: 0));

      final byId = {for (final m in chat.messages) m.id: m};
      expect(byId['20']!.authorId, isNot(controller.currentUserId));
      expect(byId['21']!.authorId, controller.currentUserId);
    });
  });

  group('list operations (U7)', () {
    test('a single event inserts; only the bulk load uses setMessages', () async {
      await ready();
      factory.callbacks!.onMessagesRetrieved!([
        for (var i = 1; i <= 500; i++)
          msg(
            i,
            createdAt:
                '2024-01-01 00:${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}',
          ),
      ]);
      expect(chat.sets, 1);
      expect(chat.messages.length, 500);
      final setsBefore = chat.sets;
      final insertsBefore = chat.inserts;

      factory.callbacks!.onMessageReceived!(
        msg(501, createdAt: '2025-01-01 00:00:00'),
      );
      factory.callbacks!.onMessageUpdated!(
        msg(501, content: 'edit', createdAt: '2025-01-01 00:00:00'),
      );

      expect(chat.sets, setsBefore);
      expect(chat.inserts, insertsBefore + 1);
      expect(chat.messages.length, 501);
      expect(texts().last.text, 'edit');
    });

    test(
      'bulk load is sorted oldest first even if the server order is not',
      () async {
        await ready();
        factory.callbacks!.onMessagesRetrieved!([
          msg(2, content: 'b', createdAt: '2024-01-02 00:00:00'),
          msg(1, content: 'a', createdAt: '2024-01-01 00:00:00'),
        ]);

        expect(texts().map((m) => m.text), ['a', 'b']);
      },
    );

    test('persisted messages are ignored when persistence is off', () async {
      controller.dispose();
      controller = ChatwootChatController(
        const ChatwootChatOptions(
          baseUrl: 'b',
          inboxIdentifier: 'i',
          enablePersistence: false,
        ),
        clientFactory: factory.call,
        chat: chat,
      );
      factory.callbacks!.onPersistedMessagesRetrieved!([msg(1)]);

      expect(chat.messages, isEmpty);
    });
  });

  group('authors and dates (U8)', () {
    test('sender-less agent messages share one stable author', () async {
      await ready();
      for (var i = 1; i <= 3; i++) {
        factory.callbacks!.onMessageReceived!(msg(i, type: 1, sender: null));
      }
      final authors = chat.messages.map((m) => m.authorId).toSet();

      expect(authors.length, 1);
      expect((await controller.resolveUser(authors.single)).id, authors.single);
    });

    test('agents with ids get their own author with name', () async {
      await ready();
      factory.callbacks!.onMessageReceived!(
        msg(1, sender: ChatwootEventMessageUser(id: 9, name: 'Ann')),
      );

      final author = chat.messages.single.authorId;
      expect((await controller.resolveUser(author)).name, 'Ann');
    });

    test(
      'an unparsable createdAt does not throw and the message is shown',
      () async {
        await ready();
        factory.callbacks!.onMessageReceived!(msg(1, createdAt: 'garbage'));

        expect(chat.messages.single.createdAt, isNotNull);
      },
    );

    test('only https avatars are used (SEC10)', () async {
      await ready();
      for (final (id, url) in [
        (3, 'http://evil.test/a.png'),
        (4, 'https://ok.test/a.png'),
      ]) {
        factory.callbacks!.onMessageReceived!(
          msg(
            id,
            sender: ChatwootEventMessageUser(id: id, name: 'A', avatarUrl: url),
          ),
        );
      }

      final images = [
        for (final m in chat.messages)
          (await controller.resolveUser(m.authorId)).imageSource,
      ];
      expect(images, [null, 'https://ok.test/a.png']);
    });

    test('a gravatar "not found" avatar is dropped', () async {
      await ready();
      factory.callbacks!.onMessageReceived!(
        msg(
          1,
          sender: ChatwootEventMessageUser(
            id: 3,
            name: 'A',
            avatarUrl: 'https://g.test/a?d=404',
          ),
        ),
      );

      final user = await controller.resolveUser(chat.messages.single.authorId);
      expect(user.imageSource, isNull);
    });
  });

  group('resolved message (U9)', () {
    test('shown once, by a system author without a remote avatar', () async {
      await ready();
      factory.callbacks!.onConversationResolved!();
      factory.callbacks!.onConversationResolved!();

      expect(chat.messages.length, 1);
      expect(
        texts().single.text,
        const ChatwootL10n().conversationResolvedMessage,
      );
      final author = await controller.resolveUser(
        chat.messages.single.authorId,
      );
      expect(author.imageSource, isNull);
      expect(author.name, const ChatwootL10n().botName);
    });

    test('resolved again after new messages is shown again', () async {
      await ready();
      factory.callbacks!.onConversationResolved!();
      factory.callbacks!.onMessageReceived!(
        msg(1, createdAt: '2999-01-01 00:00:00'),
      );
      factory.callbacks!.onConversationResolved!();

      expect(chat.messages.length, 3);
    });
  });

  group('attachments (U20)', () {
    test('attachment-only messages show the attachment label, empty ones are skipped', () async {
      await ready();
      factory.callbacks!.onMessageReceived!(
        msg(1, content: null, attachments: [<String, dynamic>{}]),
      );
      factory.callbacks!.onMessageReceived!(msg(2, content: null));
      factory.callbacks!.onMessageReceived!(msg(3, content: '  '));

      expect(chat.messages.length, 1);
      expect(texts().single.text, const ChatwootL10n().attachmentLabel);
    });

    test('https attachments become image, gallery, audio and file messages', () async {
      await ready();
      Map<String, dynamic> file(String type, String name) => {
        'file_type': type,
        'data_url': 'https://cdn.test/$name',
        'file_size': 2048,
      };
      factory.callbacks!.onMessageReceived!(
        msg(1, content: 'one', attachments: [file('image', 'a.jpg')]),
      );
      factory.callbacks!.onMessageReceived!(
        msg(
          2,
          content: 'two',
          attachments: [file('image', 'b.jpg'), file('image', 'c.jpg')],
        ),
      );
      factory.callbacks!.onMessageReceived!(
        msg(3, content: null, attachments: [file('audio', 'v.ogg')]),
      );
      factory.callbacks!.onMessageReceived!(
        msg(4, content: null, attachments: [file('file', 'doc.pdf')]),
      );
      factory.callbacks!.onMessageReceived!(
        msg(
          5,
          content: null,
          attachments: [
            {'file_type': 'image', 'data_url': 'http://insecure.test/x.jpg'},
          ],
        ),
      );

      final m = chat.messages;
      expect(m.length, 5);
      expect((m[0] as ImageMessage).source, 'https://cdn.test/a.jpg');
      expect((m[0] as ImageMessage).text, 'one');
      expect(GalleryMessage.imagesOf(m[1]), [
        'https://cdn.test/b.jpg',
        'https://cdn.test/c.jpg',
      ]);
      expect(GalleryMessage.captionOf(m[1]), 'two');
      expect((m[2] as AudioMessage).source, 'https://cdn.test/v.ogg');
      expect((m[3] as FileMessage).name, 'doc.pdf');
      expect((m[3] as FileMessage).size, 2048);
      expect((m[4] as TextMessage).text, const ChatwootL10n().attachmentLabel);
    });
  });

  group('sending attachments', () {
    test('a local preview at once, the server version once confirmed', () async {
      await ready();
      final file = ChatwootUpload.bytes(
        name: 'photo.jpg',
        bytes: Uint8List.fromList([1, 2]),
      );

      controller.sendAttachments([file]);
      await pumpEventQueue();

      final preview = chat.messages.single as ImageMessage;
      expect(preview.status, MessageStatus.sending);
      expect(client.sent.single.attachments, [file]);
      expect(client.sent.single.content, '');

      factory.callbacks!.onMessageSent!(
        msg(
          5,
          content: null,
          type: 0,
          attachments: [
            {'file_type': 'image', 'data_url': 'https://cdn.test/p.jpg'},
          ],
        ),
        client.sent.single.echoId,
      );
      await pumpEventQueue();

      final confirmed = chat.messages.single as ImageMessage;
      expect(confirmed.id, preview.id);
      expect(confirmed.source, 'https://cdn.test/p.jpg');
      expect(confirmed.status, MessageStatus.delivered);
    });

    test('a voice recording keeps its duration; a failed one resends', () async {
      await ready();
      final voice = ChatwootUpload.bytes(
        name: 'voice.wav',
        bytes: Uint8List.fromList([1, 2]),
      );
      client.sendError = StateError('offline');

      controller.sendAttachments(
        [voice],
        audioDuration: const Duration(seconds: 7),
      );
      await pumpEventQueue();
      final failed = chat.messages.single as AudioMessage;
      expect(failed.duration, const Duration(seconds: 7));
      expect(failed.status, MessageStatus.error);

      client.sendError = null;
      controller.resend(failed.id);
      await pumpEventQueue();

      expect(client.sent.single.attachments, [voice]);
    });
  });

  group('status and callbacks', () {
    test('online / typing / stopped typing / offline', () async {
      await ready();
      final cb = factory.callbacks!;
      final seen = <ChatwootChatStatus>[];
      controller.addListener(() => seen.add(controller.status));

      cb.onConversationIsOnline!();
      cb.onConversationStartedTyping!();
      cb.onConversationStoppedTyping!();
      cb.onConversationIsOffline!();

      expect(seen, [
        ChatwootChatStatus.online,
        ChatwootChatStatus.typing,
        ChatwootChatStatus.online,
        ChatwootChatStatus.offline,
      ]);
    });

    test('stopped typing while offline stays offline', () async {
      await ready();
      factory.callbacks!.onConversationStoppedTyping!();
      expect(controller.status, ChatwootChatStatus.offline);
    });

    test('consumer callbacks are forwarded', () async {
      final got = <String>[];
      controller.dispose();
      controller = make(
        callbacks: ChatwootCallbacks(
          onMessageReceived: (m) => got.add('r${m.id}'),
          onMessageSent: (m, e) => got.add('s${m.id}$e'),
          onConversationIsOnline: () => got.add('on'),
          onPing: () => got.add('ping'),
        ),
      );
      final cb = factory.callbacks!;
      cb.onMessageReceived!(msg(1));
      cb.onMessageSent!(msg(2), 'e');
      cb.onConversationIsOnline!();
      cb.onPing!();

      expect(got, ['r1', 's2e', 'on', 'ping']);
    });
  });
}
