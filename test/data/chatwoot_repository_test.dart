import 'dart:async';
import 'dart:typed_data';

import 'package:chatwoot_sdk/src/core/chatwoot_callbacks.dart';
import 'package:chatwoot_sdk/src/data/local/dao/chatwoot_messages_dao.dart';
import 'package:chatwoot_sdk/src/core/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/src/core/chatwoot_upload.dart';
import 'package:chatwoot_sdk/src/data/chatwoot_repository.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_message.dart';
import 'package:chatwoot_sdk/src/data/remote/api/requests/chatwoot_new_message_request.dart';
import 'package:chatwoot_sdk/src/data/remote/realtime/chatwoot_socket.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fakes.dart';
import '../utils/fixtures.dart';

/// Behaviour tests: a real in-memory [LocalStorage], a scripted service and
/// recording callbacks.
void main() {
  late FakeClientService service;
  late LocalStorage storage;
  late ChatwootRepositoryImpl repo;
  late FakeSocketHub hub;

  // recorded callback invocations
  late List<ChatwootClientException> errors;
  late List<ChatwootMessage> retrieved;
  late List<ChatwootMessage> persistedRetrieved;
  late List<(ChatwootMessage, String)> sent;
  late List<(ChatwootMessage, String)> delivered;
  late List<ChatwootMessage> received;
  late List<ChatwootMessage> updated;
  late List<String> events;

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
    repo = ChatwootRepositoryImpl(
      clientService: service,
      localStorage: storage,
      socket: ChatwootSocket(
        url: Uri.parse('wss://h/cable'),
        tokenProvider: () => storage.contact.get()?.pubsubToken,
        connect: hub.connect,
      ),
      streamCallbacks: ChatwootCallbacks(
        onError: errors.add,
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
        ChatwootClientExceptionType.GET_MESSAGES_FAILED,
      );

      await repo.getMessages();

      expect(
        errors.single.type,
        ChatwootClientExceptionType.GET_MESSAGES_FAILED,
      );
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
          expect(
            errors.single.type,
            ChatwootClientExceptionType.GET_MESSAGES_FAILED,
          );
          expect(retrieved, isEmpty);
        });
      }

      test('a storage that throws synchronously is reported', () async {
        final broken = ChatwootRepositoryImpl(
          clientService: service,
          localStorage: LocalStorage(
            contact: storage.contact,
            conversation: storage.conversation,
            user: storage.user,
            messages: _ThrowingDao(sync: true),
          ),
          socket: ChatwootSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ChatwootCallbacks(onError: errors.add),
        );
        service.messagesResult = [message(1)];

        await broken.getMessages();

        expect(
          errors.single.type,
          ChatwootClientExceptionType.GET_MESSAGES_FAILED,
        );
        await broken.dispose();
      });

      test('a failing async write is only logged: messages are still '
          'delivered', () async {
        final broken = ChatwootRepositoryImpl(
          clientService: service,
          localStorage: LocalStorage(
            contact: storage.contact,
            conversation: storage.conversation,
            user: storage.user,
            messages: _ThrowingDao(sync: false),
          ),
          socket: ChatwootSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ChatwootCallbacks(
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
        final throwing = ChatwootRepositoryImpl(
          clientService: service,
          localStorage: storage,
          socket: ChatwootSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ChatwootCallbacks(
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
        final throwing = ChatwootRepositoryImpl(
          clientService: service,
          localStorage: storage,
          socket: ChatwootSocket(
            url: Uri.parse('wss://h/cable'),
            tokenProvider: () => null,
            connect: hub.connect,
          ),
          streamCallbacks: ChatwootCallbacks(onError: (_) => throw 'bad'),
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

  group('sendMessage', () {
    final request = ChatwootNewMessageRequest(content: 'hi', echoId: 'echo-1');

    test('stores and reports the created message with the echo id', () async {
      service.createMessageResult = message(5);

      await repo.sendMessage(request);

      expect(sent.single.$1.id, 5);
      expect(sent.single.$2, 'echo-1');
      expect(storage.messages.getMessage(5), isNotNull);
    });

    test('attachments go through the multipart call', () async {
      service.createMessageResult = message(6);
      final file = ChatwootUpload.bytes(
        name: 'a.pdf',
        bytes: Uint8List.fromList([1]),
      );

      await repo.sendMessage(request, attachments: [file]);

      expect(service.uploadedAttachments.single, [file]);
      expect(sent.single.$2, 'echo-1');
    });

    test('a failure is reported with the echo id as data', () async {
      service.createMessageResult = failure(
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
      );

      await repo.sendMessage(request);

      expect(
        errors.single.type,
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
      );
      expect(errors.single.data, 'echo-1');
      expect(storage.messages.getMessages(), isEmpty);
    });
  });

  group('sendMessage failures (S18)', () {
    final request = ChatwootNewMessageRequest(content: 'hi', echoId: 'echo-1');

    for (final error in <Object>[
      const FormatException('bad json'),
      StateError('boom'),
      TypeError(),
    ]) {
      test('${error.runtimeType} carries the echo id to onError', () async {
        service.createMessageResult = error;

        await repo.sendMessage(request);

        expect(
          errors.single.type,
          ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
        );
        expect(errors.single.data, 'echo-1');
      });
    }
  });

  group('initialize', () {
    test('saves user, contact and the refreshed conversation', () async {
      final conv = conversation(id: 7);
      service
        ..contactResult = contact(pubsubToken: null)
        ..conversationsResult = [conv];
      await storage.conversation.save(conversation(id: 7));

      await repo.initialize(user());

      expect(storage.user.get(), user());
      expect(storage.contact.get(), contact(pubsubToken: null));
      expect(storage.conversation.get(), conv);
      expect(errors, isEmpty);
    });

    test('works without a user', () async {
      service
        ..contactResult = contact(pubsubToken: null)
        ..conversationsResult = [conversation()];
      await storage.conversation.save(conversation());

      await repo.initialize(null);

      expect(storage.user.get(), isNull);
      expect(storage.contact.get(), isNotNull);
    });

    test('starts listening when the contact has a pubsub token', () async {
      service
        ..contactResult = contact(pubsubToken: 'tok')
        ..conversationsResult = [conversation()];
      await storage.conversation.save(conversation());

      await repo.initialize(null);

      expect(hub.urls, hasLength(1));
    });

    // P5: the missing persisted conversation used to be a null-check crash
    test(
      'no conversation after refresh: reports an error, does not throw',
      () async {
        service
          ..contactResult = contact(pubsubToken: null)
          ..conversationsResult = [conversation()];
        // storage.conversation is empty

        await repo.initialize(null);

        expect(
          errors.single.type,
          ChatwootClientExceptionType.GET_CONVERSATION_FAILED,
        );
      },
    );

    test('a failing service call is reported', () async {
      service.contactResult = failure(
        ChatwootClientExceptionType.GET_CONTACT_FAILED,
      );

      await repo.initialize(null);

      expect(
        errors.single.type,
        ChatwootClientExceptionType.GET_CONTACT_FAILED,
      );
    });

    test('an unexpected error is wrapped and reported, never thrown', () async {
      service.contactResult = 'not a contact'; // cast error inside the service

      await repo.initialize(null);

      expect(
        errors.single.type,
        ChatwootClientExceptionType.CREATE_CLIENT_FAILED,
      );
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

    test('clear(clearChatwootUserStorage: false) keeps the contact', () async {
      await storage.contact.save(contact());
      await storage.messages.saveMessage(message(1));

      await repo.clear(clearChatwootUserStorage: false);

      expect(storage.contact.get(), isNotNull);
      expect(storage.messages.getMessages(), isEmpty);
    });
  });
}

class _ThrowingDao extends InMemoryChatwootMessagesDao {
  _ThrowingDao({required this.sync});

  final bool sync;

  @override
  Future<void> saveAllMessages(List<ChatwootMessage> messages) {
    if (sync) throw StateError('disk on fire');
    return Future.error(StateError('disk on fire'));
  }
}
