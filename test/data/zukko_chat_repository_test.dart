import 'dart:async';
import 'dart:typed_data';

import 'package:zukko_chat_flutter/src/core/zukko_chat_callbacks.dart';
import 'package:zukko_chat_flutter/src/data/local/dao/zukko_chat_messages_dao.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/data/zukko_chat_repository.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_message.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_socket.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fakes.dart';
import '../utils/fixtures.dart';

/// Behaviour tests: a real in-memory [LocalStorage], a scripted service and
/// recording callbacks.
void main() {
  late FakeClientService service;
  late LocalStorage storage;
  late ZukkoChatRepositoryImpl repo;
  late FakeSocketHub hub;

  // recorded callback invocations
  late List<ZukkoChatException> errors;
  late List<ZukkoChatMessage> retrieved;
  late List<ZukkoChatMessage> persistedRetrieved;
  late List<(ZukkoChatMessage, String)> sent;
  late List<(ZukkoChatMessage, String)> delivered;
  late List<ZukkoChatMessage> received;
  late List<ZukkoChatMessage> updated;
  late List<String> events;
  late List<int> conversationUpdates;

  setUp(() {
    service = FakeClientService();
    hub = FakeSocketHub();
    storage = LocalStorage.inMemory();
    errors = [];
    retrieved = [];
    persistedRetrieved = [];
    sent = [];
    delivered = [];
    received = [];
    updated = [];
    events = [];
    conversationUpdates = [];
    repo = ZukkoChatRepositoryImpl(
      clientService: service,
      localStorage: storage,
      socket: ZukkoChatSocket(
        url: Uri.parse('wss://h/cable'),
        tokenProvider: () => storage.contact.get()?.pubsubToken,
        connect: hub.connect,
      ),
      streamCallbacks: ZukkoChatCallbacks(
        onError: errors.add,
        onConversationUpdated: (c) => conversationUpdates.add(c.id),
        onMessagesRetrieved: retrieved.addAll,
        onPersistedMessagesRetrieved: persistedRetrieved.addAll,
        onMessageSent: (m, echo) => sent.add((m, echo)),
        onMessageDelivered: (m, echo) => delivered.add((m, echo)),
        onMessageReceived: received.add,
        onMessageUpdated: updated.add,
        onWelcome: () => events.add('welcome'),
        onPing: () => events.add('ping'),
        onConfirmedSubscription: () => events.add('confirmed'),
        onConversationStartedTyping: () => events.add('typing_on'),
        onConversationStoppedTyping: () => events.add('typing_off'),
        onConversationIsOnline: () => events.add('online'),
        onConversationIsOffline: () => events.add('offline'),
        onConversationResolved: () => events.add('resolved'),
      ),
    );
  });

  tearDown(() => repo.dispose());

  group('getMessages / getPersistedMessages', () {
    test('fetched messages are stored and reported', () async {
      service.messagesResult = [message(2), message(1)];

      await repo.getMessages();

      expect(retrieved.map((m) => m.id), [2, 1]);
      expect(storage.messages.getMessages().map((m) => m.id), [1, 2]);
      expect(errors, isEmpty);
    });

    test('a failing fetch reports the error and stores nothing', () async {
      service.messagesResult = failure(
        ZukkoChatExceptionType.getMessagesFailed,
      );

      await repo.getMessages();

      expect(errors.single.type, ZukkoChatExceptionType.getMessagesFailed);
      expect(retrieved, isEmpty);
      expect(storage.messages.getMessages(), isEmpty);
    });

    // F7 / SEC6: getMessages is also called unawaited after a reconnect
    group('never throws (F7)', () {
      for (final entry in <String, Object>{
        'a non-typed error from the service': StateError('boom'),
        'a RangeError from the service': RangeError('poisoned'),
      }.entries) {
        test(entry.key, () async {
          service.messagesResult = entry.value;
          final uncaught = <Object>[];

          await runZonedGuarded(
            () => repo.getMessages(),
            (e, _) => uncaught.add(e),
          );

          expect(uncaught, isEmpty);
          expect(errors.single.type, ZukkoChatExceptionType.getMessagesFailed);
          expect(retrieved, isEmpty);
        });
      }

      test('a storage that throws synchronously is only logged: messages are '
          'still delivered (R6)', () async {
        final broken = ZukkoChatRepositoryImpl(
          clientService: service,
          localStorage: LocalStorage(
            contact: storage.contact,
            conversation: storage.conversation,
            messages: _ThrowingDao(sync: true),
          ),
          socket: ZukkoChatSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ZukkoChatCallbacks(
            onError: errors.add,
            onMessagesRetrieved: retrieved.addAll,
          ),
        );
        service.messagesResult = [message(1)];

        await broken.getMessages();

        expect(errors, isEmpty);
        expect(retrieved.map((m) => m.id), [1]);
        await broken.dispose();
      });

      test('a failing async write is only logged: messages are still '
          'delivered', () async {
        final broken = ZukkoChatRepositoryImpl(
          clientService: service,
          localStorage: LocalStorage(
            contact: storage.contact,
            conversation: storage.conversation,
            messages: _ThrowingDao(sync: false),
          ),
          socket: ZukkoChatSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ZukkoChatCallbacks(
            onError: errors.add,
            onMessagesRetrieved: retrieved.addAll,
          ),
        );
        service.messagesResult = [message(1)];

        await broken.getMessages();

        expect(errors, isEmpty);
        expect(retrieved.map((m) => m.id), [1]);
        await broken.dispose();
      });

      test('a host callback that throws is reported through onError, '
          'not rethrown', () async {
        final throwing = ZukkoChatRepositoryImpl(
          clientService: service,
          localStorage: storage,
          socket: ZukkoChatSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ZukkoChatCallbacks(
            onError: errors.add,
            onMessagesRetrieved: (_) => throw StateError('app bug'),
          ),
        );
        service.messagesResult = [message(1)];

        await throwing.getMessages();

        expect(errors, hasLength(1));
        await throwing.dispose();
      });

      test('an onError callback that throws is swallowed', () async {
        final throwing = ZukkoChatRepositoryImpl(
          clientService: service,
          localStorage: storage,
          socket: ZukkoChatSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ZukkoChatCallbacks(onError: (_) => throw 'bad'),
        );
        service.messagesResult = StateError('x');

        await throwing.getMessages();
        await throwing.dispose();
      });
    });

    test('persisted messages are reported oldest first', () async {
      await storage.messages.saveAllMessages([message(2), message(1)]);

      repo.getPersistedMessages();

      expect(persistedRetrieved.map((m) => m.id), [1, 2]);
    });

    test('nothing is reported when nothing is persisted', () {
      repo.getPersistedMessages();

      expect(persistedRetrieved, isEmpty);
    });
  });

  group('older history paging', () {
    // sortable timestamps for ids up to 3599
    ZukkoChatMessage m(int id) => message(
      id,
      createdAt:
          '2024-01-01 00:${(id ~/ 60).toString().padLeft(2, '0')}:'
          '${(id % 60).toString().padLeft(2, '0')}',
    );

    test(
      'a cache saved with 500 messages reports the newest 20, oldest first',
      () async {
        await storage.messages.saveAllMessages([
          for (var i = 1; i <= 500; i++) m(i),
        ]);

        repo.getPersistedMessages();

        expect(persistedRetrieved.map((x) => x.id), [
          for (var i = 481; i <= 500; i++) i,
        ]);
      },
    );

    test('a small cache is reported whole', () async {
      await storage.messages.saveAllMessages([m(1), m(2)]);

      repo.getPersistedMessages();

      expect(persistedRetrieved.map((x) => x.id), [1, 2]);
    });

    test('getOlderMessages asks before=<id>, returns the page, persists and '
        'reports nothing', () async {
      await storage.messages.saveAllMessages([m(100)]);
      service.messagesResult = [m(60), m(61)];

      final page = await repo.getOlderMessages(100);

      expect(page!.map((x) => x.id), [60, 61]);
      expect(service.messageCursors.single, (before: 100, after: null));
      expect(storage.messages.getMessages().map((x) => x.id), [100]);
      expect(retrieved, isEmpty);
    });

    test('older pages never evict the newest cached messages', () async {
      final newest = [for (var i = 981; i <= 1000; i++) m(i)];
      await storage.messages.saveAllMessages(newest);
      service.messagesResult = [for (var i = 961; i <= 980; i++) m(i)];

      await repo.getOlderMessages(981);

      final stored = storage.messages.getMessages().map((x) => x.id).toList();
      expect(stored.length, 20);
      expect(stored.first, 981);
      expect(stored.last, 1000);
    });

    test(
      'a failure returns null, reports it, and the next call retries',
      () async {
        service.messagesResult = failure(
          ZukkoChatExceptionType.getMessagesFailed,
        );

        expect(await repo.getOlderMessages(100), isNull);
        expect(errors.single.type, ZukkoChatExceptionType.getMessagesFailed);

        service.messagesResult = [m(99)];
        expect((await repo.getOlderMessages(100))!.single.id, 99);
        expect(service.messageCursors.length, 2);
      },
    );
  });

  group('sendMessage', () {
    final request = ZukkoChatNewMessageRequest(content: 'hi', echoId: 'echo-1');

    test('stores and reports the created message with the echo id', () async {
      service.createMessageResult = message(5);

      await repo.sendMessage(request);

      expect(sent.single.$1.id, 5);
      expect(sent.single.$2, 'echo-1');
      expect(storage.messages.getMessage(5), isNotNull);
    });

    test('attachments go through the multipart call', () async {
      service.createMessageResult = message(6);
      final file = ZukkoChatUpload.bytes(
        name: 'a.pdf',
        bytes: Uint8List.fromList([1]),
      );

      await repo.sendMessage(request, attachments: [file]);

      expect(service.uploadedAttachments.single, [file]);
      expect(sent.single.$2, 'echo-1');
    });

    test('a failure is reported with the echo id as data', () async {
      service.createMessageResult = failure(
        ZukkoChatExceptionType.sendMessageFailed,
      );

      await repo.sendMessage(request);

      expect(errors.single.type, ZukkoChatExceptionType.sendMessageFailed);
      expect(errors.single.data, 'echo-1');
      expect(storage.messages.getMessages(), isEmpty);
    });
  });

  group('sendMessage failures (S18)', () {
    final request = ZukkoChatNewMessageRequest(content: 'hi', echoId: 'echo-1');

    for (final error in <Object>[
      const FormatException('bad json'),
      StateError('boom'),
      TypeError(),
    ]) {
      test('${error.runtimeType} carries the echo id to onError', () async {
        service.createMessageResult = error;

        await repo.sendMessage(request);

        expect(errors.single.type, ZukkoChatExceptionType.sendMessageFailed);
        expect(errors.single.data, 'echo-1');
      });
    }
  });

  group('initialize', () {
    test('saves the current conversation', () async {
      final conv = conversation(id: 7);
      service.conversationResult = conv;

      await repo.initialize();

      expect(storage.conversation.get(), conv);
      expect(errors, isEmpty);
    });

    test('reports the initial conversation, but not after dispose', () async {
      service.conversationResult = conversation(id: 7);
      await repo.initialize();
      expect(conversationUpdates, [7]);

      final gate = service.conversationGate = Completer<void>();
      final pending = repo.initialize();
      await repo.dispose();
      gate.complete();
      await pending;

      expect(conversationUpdates, [7]);
    });

    test('a contact without a conversation yet is not an error', () async {
      service.conversationResult = null;

      await repo.initialize();

      expect(storage.conversation.get(), isNull);
      expect(errors, isEmpty);
    });

    test('another current conversation drops the old messages', () async {
      await storage.conversation.save(conversation(id: 7));
      await storage.messages.saveMessage(message(1));
      service.conversationResult = conversation(id: 9);

      await repo.initialize();

      expect(storage.conversation.get()!.id, 9);
      expect(storage.messages.getMessages(), isEmpty);
    });

    test('starts listening when the contact has a pubsub token', () async {
      await storage.contact.save(contact(pubsubToken: 'tok'));
      service.conversationResult = conversation();

      await repo.initialize();

      expect(hub.urls, hasLength(1));
    });

    test('does not connect without a pubsub token', () async {
      await storage.contact.save(contact(pubsubToken: null));
      service.conversationResult = conversation();

      await repo.initialize();

      expect(hub.urls, isEmpty);
    });

    test('a failing service call is reported', () async {
      service.conversationResult = failure(
        ZukkoChatExceptionType.getConversationFailed,
      );

      await repo.initialize();

      expect(errors.single.type, ZukkoChatExceptionType.getConversationFailed);
    });

    test('an unexpected error is wrapped and reported, never thrown', () async {
      service.conversationResult = 'not a conversation'; // cast error

      await repo.initialize();

      expect(errors.single.type, ZukkoChatExceptionType.createClientFailed);
    });
  });

  group('first message creates the conversation', () {
    test('its conversation becomes the stored one', () async {
      service.createMessageResult = message(100);

      await repo.sendMessage(
        ZukkoChatNewMessageRequest(content: 'hi', echoId: 'e'),
      );

      expect(storage.conversation.get()!.id, 7);
    });
  });

  group('typing / last seen', () {
    test('forwarded to the service', () async {
      await repo.setTyping(true);
      await repo.markSeen();

      expect(service.typing, [true]);
      expect(service.updateLastSeenCalls, 1);
    });

    test('failures are swallowed, never reported', () async {
      service.typingResult = StateError('404');

      await repo.setTyping(false);

      expect(errors, isEmpty);
    });
  });

  group('getMessages(after:)', () {
    test('pages of 100 are followed until a short page', () async {
      final full = [for (var i = 1; i <= 100; i++) message(i)];
      service.messagePages = [
        full,
        [message(101)],
      ];

      await repo.getMessages(after: 0);

      expect(service.messageCursors.map((c) => c.after), [0, 100]);
      expect(storage.messages.getMessages(), hasLength(101));
      expect(retrieved, hasLength(101));
    });
  });

  group('clear / dispose', () {
    test('clear removes the instance data', () async {
      await storage.contact.save(contact());
      await storage.messages.saveMessage(message(1));

      await repo.clear();

      expect(storage.contact.get(), isNull);
      expect(storage.messages.getMessages(), isEmpty);
    });

    test('clear(clearContact: false) keeps the contact', () async {
      await storage.contact.save(contact());
      await storage.messages.saveMessage(message(1));

      await repo.clear(clearContact: false);

      expect(storage.contact.get(), isNotNull);
      expect(storage.messages.getMessages(), isEmpty);
    });
  });
}

class _ThrowingDao extends InMemoryZukkoChatMessagesDao {
  _ThrowingDao({required this.sync});

  final bool sync;

  @override
  Future<void> saveAllMessages(List<ZukkoChatMessage> messages) {
    if (sync) throw StateError('disk on fire');
    return Future.error(StateError('disk on fire'));
  }
}
