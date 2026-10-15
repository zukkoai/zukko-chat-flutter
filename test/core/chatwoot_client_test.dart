import 'dart:async';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/data/chatwoot_repository.dart';
import 'package:chatwoot_sdk/src/data/local/key_store.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:chatwoot_sdk/src/data/remote/api/requests/chatwoot_new_message_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../utils/fake_chat_server.dart';
import '../utils/fixtures.dart';
import '../utils/hive_test_env.dart';

/// Records what the client forwards to its repository.
class _RecordingRepository extends Fake implements ChatwootRepository {
  final log = <String>[];
  var disposeCount = 0;

  @override
  void getPersistedMessages() => log.add('getPersistedMessages');

  @override
  Future<void> getMessages() async => log.add('getMessages');

  @override
  Future<void> sendMessage(
    ChatwootNewMessageRequest request, {
    List<ChatwootUpload> attachments = const [],
  }) async => log.add(
    'sendMessage ${request.content} ${request.echoId} '
    '${attachments.length}',
  );

  @override
  bool sendAction(ChatwootActionType action) {
    log.add('sendAction $action');
    return true;
  }

  @override
  Future<void> clear({bool clearChatwootUserStorage = true}) async =>
      log.add('clear keepUser=${!clearChatwootUserStorage}');

  @override
  Future<void> dispose() async => disposeCount++;
}

void main() {
  final env = HiveTestEnv();
  late FakeChatServer server;

  setUpAll(() async {
    env.setUpAll();
    server = await FakeChatServer.start();
  });
  tearDown(env.tearDown);
  tearDownAll(() async {
    await server.close();
    await env.tearDownAll();
  });

  group('delegation to the repository', () {
    late _RecordingRepository repo;
    late ChatwootClient client;

    setUp(() {
      repo = _RecordingRepository();
      client = ChatwootClient.withRepository(
        repo,
        baseUrl: 'https://x',
        inboxIdentifier: 'in',
      );
    });

    test(
      'loadMessages: persisted first, then remote, and it is awaitable',
      () async {
        await client.loadMessages();

        expect(repo.log, ['getPersistedMessages', 'getMessages']);
      },
    );

    test('sendMessage / sendAction / clearClientData', () async {
      await client.sendMessage(content: 'hi', echoId: 'e');
      await client.sendAction(ChatwootActionType.update_presence);
      await client.clearClientData();

      expect(repo.log, [
        'sendMessage hi e 0',
        'sendAction ChatwootActionType.update_presence',
        'clear keepUser=true',
      ]);
    });

    // P4: second dispose used to throw (null-check on the removed container)
    test('dispose is idempotent', () async {
      await client.dispose();
      await client.dispose();

      expect(repo.disposeCount, 1);
    });
  });

  group('create() wiring against a real HTTP server (no persistence)', () {
    late List<ChatwootClientException> errors;
    late List<ChatwootMessage> messages;

    setUp(() {
      errors = [];
      messages = [];
      server.requests.clear();
      server.forceStatus = null;
    });

    Future<ChatwootClient> create({bool persist = false, ChatwootUser? user}) =>
        ChatwootClient.create(
          baseUrl: server.baseUrl,
          inboxIdentifier: 'inbox',
          user: user,
          enablePersistence: persist,
          callbacks: ChatwootCallbacks(
            onError: errors.add,
            onMessagesRetrieved: messages.addAll,
          ),
        );

    test(
      'refreshes contact and conversation before create() completes',
      () async {
        final client = await create();

        expect(
          server.requests,
          containsAll([
            'POST /public/api/v1/inboxes/inbox/contacts',
            'POST /public/api/v1/inboxes/inbox/contacts/source-1/conversations',
            'GET /public/api/v1/inboxes/inbox/contacts/source-1',
            'GET /public/api/v1/inboxes/inbox/contacts/source-1/conversations',
          ]),
        );
        expect(errors, isEmpty);
        await client.loadMessages();
        expect(messages.map((m) => m.id), [1, 2]);
        await client.dispose();
      },
    );

    // P4
    test('two clients with the same key are independent; dispose of one '
        'leaves the other working', () async {
      final a = await create();
      final b = await create();
      // non-persisted clients no longer share state: each created its own contact
      expect(server.count('POST', (p) => p.endsWith('/contacts')), 2);

      await a.dispose();
      await b.loadMessages();
      await b.dispose();
      await a.dispose(); // double dispose

      expect(messages, hasLength(2));
      expect(errors, isEmpty);
    });

    test('dispose can be called repeatedly', () async {
      final client = await create();

      await client.dispose();
      await client.dispose();
    });

    // P5: errors used to escape as uncaught async errors / were lost
    test('init failure is delivered to onError before create() completes, '
        'with no uncaught error', () async {
      server.forceStatus = 500;
      final uncaught = <Object>[];
      late ChatwootClient client;

      await runZonedGuarded(() async {
        client = await create();
        await pumpEventQueue();
      }, (e, _) => uncaught.add(e));

      expect(uncaught, isEmpty);
      expect(errors, isNotEmpty);
      expect(errors.first.type, isA<ChatwootClientExceptionType>());
      await client.dispose();
    });

    test('unreachable server: onError, no throw', () async {
      final client = await ChatwootClient.create(
        baseUrl: 'http://127.0.0.1:1',
        inboxIdentifier: 'inbox',
        enablePersistence: false,
        callbacks: ChatwootCallbacks(onError: errors.add),
      );

      expect(errors, isNotEmpty);
      await client.dispose();
    });
  });

  // SEC4
  group('create() base url policy', () {
    test('plain http to a public host throws ArgumentError, nothing is '
        'opened', () async {
      await expectLater(
        ChatwootClient.create(
          baseUrl: 'http://chat.example.com',
          inboxIdentifier: 'in',
          enablePersistence: false,
        ),
        throwsArgumentError,
      );
    });

    for (final url in ['ftp://chat.example.com', 'chat.example.com', '']) {
      test('"$url" is refused', () async {
        await expectLater(
          ChatwootClient.create(
            baseUrl: url,
            inboxIdentifier: 'in',
            enablePersistence: false,
            allowInsecure: true,
          ),
          throwsArgumentError,
        );
      });
    }

    test('allowInsecure lets http to a non-loopback host through to the '
        'network layer', () async {
      final errors = <ChatwootClientException>[];

      final client = await ChatwootClient.create(
        baseUrl: 'http://nonexistent.invalid',
        inboxIdentifier: 'in',
        enablePersistence: false,
        allowInsecure: true,
        callbacks: ChatwootCallbacks(onError: errors.add),
      );

      expect(errors, isNotEmpty); // unreachable, but it was attempted
      await client.dispose();
    });
  });

  // F14
  test('sendAction completes with false while not subscribed', () async {
    final client = await ChatwootClient.create(
      baseUrl: server.baseUrl,
      inboxIdentifier: 'inbox',
      enablePersistence: false,
    );

    expect(
      await client.sendAction(ChatwootActionType.update_presence),
      isFalse,
    );
    await client.dispose();
  });

  // F20
  group('storage failure', () {
    test('openDB failing: onError(STORAGE_FAILED) and the client works '
        'in memory', () async {
      final saved = LocalStorage.keyStore;
      LocalStorage.keyStore = _BrokenKeyStore();
      addTearDown(() => LocalStorage.keyStore = saved);
      final errors = <ChatwootClientException>[];
      server.requests.clear();

      final client = await ChatwootClient.create(
        baseUrl: server.baseUrl,
        inboxIdentifier: 'inbox',
        callbacks: ChatwootCallbacks(onError: errors.add),
      );

      expect(errors.map((e) => e.type), [
        ChatwootClientExceptionType.STORAGE_FAILED,
      ]);
      expect(
        server.count('POST', (p) => p.endsWith('/contacts')),
        1,
      ); // still talks to the server
      await client.dispose();
    });
  });

  // SEC5 + SEC3 through create()
  group('identifier hash', () {
    Future<ChatwootClient> create(String? hash) => ChatwootClient.create(
      baseUrl: server.baseUrl,
      inboxIdentifier: 'inbox',
      user: ChatwootUser(identifier: 'u', identifierHash: hash),
    );

    test('same identifier with another hash does not reuse the stored '
        'contact; the same hash does', () async {
      server.requests.clear();
      int contacts() => server.count('POST', (p) => p.endsWith('/contacts'));

      await (await create('hash-1')).dispose();
      await (await create('hash-1')).dispose();
      expect(contacts(), 1);

      await (await create('hash-FORGED')).dispose();
      expect(contacts(), 2);
    });

    test('the hash is never written to disk', () async {
      final client = await create('hash-1');
      final key = ChatwootClient.getClientInstanceKey(
        baseUrl: server.baseUrl,
        inboxIdentifier: 'inbox',
        userIdentifier: 'u',
        identifierHash: 'hash-1',
      );

      // what a new process reads from disk
      final onDisk = Hive.box<ChatwootUser>(ChatwootBoxNames.users).get(key)!;
      expect(onDisk.identifier, 'u');
      expect(onDisk.identifierHash, isNull);
      await client.dispose();
    });

    test('clearData needs the same hash to find the instance', () async {
      await (await create('hash-1')).dispose();
      final key = ChatwootClient.getClientInstanceKey(
        baseUrl: server.baseUrl,
        inboxIdentifier: 'inbox',
        userIdentifier: 'u',
        identifierHash: 'hash-1',
      );

      await ChatwootClient.clearData(
        baseUrl: server.baseUrl,
        inboxIdentifier: 'inbox',
        userIdentifier: 'u',
        identifierHash: 'hash-1',
      );

      expect(LocalStorage.persisted(key).contact.get(), isNull);
    });
  });

  group('persistence through the public API', () {
    late String key;

    setUp(() {
      key = ChatwootClient.getClientInstanceKey(
        baseUrl: 'https://a.example',
        inboxIdentifier: 'inbox',
        userIdentifier: 'u1',
      );
    });

    Future<void> seed(String instanceKey) async {
      final s = LocalStorage.persisted(instanceKey);
      await s.contact.save(contact());
      await s.conversation.save(conversation());
      await s.user.save(user());
      await s.messages.saveAllMessages([message(1), message(2)]);
    }

    void expectEmpty(String instanceKey) {
      final s = LocalStorage.persisted(instanceKey);
      expect(s.contact.get(), isNull);
      expect(s.conversation.get(), isNull);
      expect(s.user.get(), isNull);
      expect(s.messages.getMessages(), isEmpty);
    }

    // P1: used to build the key "" and so delete nothing
    test('clearData clears the target instance and only that one', () async {
      await env.open();
      final other = ChatwootClient.getClientInstanceKey(
        baseUrl: 'https://a.example',
        inboxIdentifier: 'inbox',
        userIdentifier: 'u2',
      );
      await seed(key);
      await seed(other);

      await ChatwootClient.clearData(
        baseUrl: 'https://a.example',
        inboxIdentifier: 'inbox',
        userIdentifier: 'u1',
      );

      expectEmpty(key);
      expect(LocalStorage.persisted(other).contact.get(), isNotNull);
      expect(
        LocalStorage.persisted(other).messages.getMessages(),
        hasLength(2),
      );
    });

    // P2: used to throw "Box not found" because nothing opened the boxes
    test('clearData works before any box is open (fresh process)', () async {
      await ChatwootClient.clearData(
        baseUrl: 'https://a.example',
        inboxIdentifier: 'inbox',
      );
    });

    test('clearAllData works before any box is open (fresh process)', () async {
      await ChatwootClient.clearAllData();
    });

    test('clearAllData removes every instance', () async {
      await env.open();
      await seed(key);
      await seed('another');

      await ChatwootClient.clearAllData();

      expectEmpty(key);
      expectEmpty('another');
    });

    // P3: second call used to hit a disposed container
    test('clearAllData can be called twice', () async {
      await ChatwootClient.clearAllData();
      await ChatwootClient.clearAllData();
    });

    test('clearData for a user-less instance (P10)', () async {
      await env.open();
      final anonymous = ChatwootClient.getClientInstanceKey(
        baseUrl: 'https://a.example',
        inboxIdentifier: 'inbox',
      );
      await seed(anonymous);
      await seed(key);

      await ChatwootClient.clearData(
        baseUrl: 'https://a.example',
        inboxIdentifier: 'inbox',
      );

      expectEmpty(anonymous);
      expect(LocalStorage.persisted(key).contact.get(), isNotNull);
    });

    test(
      'persisted clients with the same key reuse the stored contact',
      () async {
        server.requests.clear();
        Future<ChatwootClient> create() => ChatwootClient.create(
          baseUrl: server.baseUrl,
          inboxIdentifier: 'inbox',
        );

        final first = await create();
        final createdContacts = server.count(
          'POST',
          (p) => p.endsWith('/contacts'),
        );
        await first.dispose();
        final second = await create();
        await second.dispose();

        expect(createdContacts, 1);
        expect(server.count('POST', (p) => p.endsWith('/contacts')), 1);
      },
    );
  });
}

class _BrokenKeyStore implements ChatwootKeyStore {
  @override
  Future<List<int>?> read() => throw StateError('keystore unavailable');

  @override
  Future<void> write(List<int> key) => throw StateError('keystore unavailable');
}
