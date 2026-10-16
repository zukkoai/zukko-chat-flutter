import 'dart:async';

import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:zukko_chat_flutter/src/data/zukko_chat_repository.dart';
import 'package:zukko_chat_flutter/src/data/local/key_store.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_database.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/local/zukko_chat_box_names.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../utils/fake_chat_server.dart';
import '../utils/fixtures.dart';
import '../utils/hive_test_env.dart';

/// Records what the client forwards to its repository.
class _RecordingRepository extends Fake implements ZukkoChatRepository {
  final log = <String>[];
  var disposeCount = 0;

  @override
  void getPersistedMessages() => log.add('getPersistedMessages');

  @override
  Future<void> getMessages({int? after}) async =>
      log.add(after == null ? 'getMessages' : 'getMessages after=$after');

  @override
  Future<void> setTyping(bool on) async => log.add('setTyping $on');

  @override
  Future<void> markSeen() async => log.add('markSeen');

  @override
  Future<void> sendMessage(
    ZukkoChatNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  }) async => log.add(
    'sendMessage ${request.content} ${request.echoId} '
    '${attachments.length}',
  );

  @override
  bool sendAction(ZukkoChatActionType action) {
    log.add('sendAction $action');
    return true;
  }

  @override
  Future<void> clear({bool clearContact = true}) async =>
      log.add('clear keepUser=${!clearContact}');

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
    late ZukkoChatClient client;

    setUp(() {
      repo = _RecordingRepository();
      client = ZukkoChatClient.withRepository(repo);
    });

    test(
      'loadMessages: persisted first, then remote, and it is awaitable',
      () async {
        await client.loadMessages();

        expect(repo.log, ['getPersistedMessages', 'getMessages']);
      },
    );

    test('sendMessage / setTyping / markSeen / sendAction / clear', () async {
      await client.sendMessage(content: 'hi', echoId: 'e', replyTo: 5);
      await client.setTyping(true);
      await client.markSeen();
      await client.sendAction(ZukkoChatActionType.updatePresence);
      await client.clearClientData();

      expect(client.config, isNull);
      expect(repo.log, [
        'sendMessage hi e 0',
        'setTyping true',
        'markSeen',
        'sendAction ZukkoChatActionType.updatePresence',
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
    late List<ZukkoChatException> errors;
    late List<ZukkoChatMessage> messages;

    setUp(() {
      errors = [];
      messages = [];
      server.calls.clear();
      server.forceStatus = null;
      server.hasConversation = true;
      server.contacts.clear();
    });

    Future<ZukkoChatClient> create({
      bool persist = false,
      ZukkoChatUser? user,
    }) => ZukkoChatClient.create(
      baseUrl: server.baseUrl,
      websiteToken: FakeChatServer.websiteToken,
      user: user,
      enablePersistence: persist,
      callbacks: ZukkoChatCallbacks(
        onError: errors.add,
        onMessagesRetrieved: messages.addAll,
      ),
    );

    test('establishes the session and reads the conversation before create() '
        'completes', () async {
      final client = await create();

      expect(server.requests, [
        'POST /api/v1/widget/config',
        'GET /api/v1/widget/conversations',
      ]);
      expect(client.config?.websiteName, 'Zukko');
      expect(
        server.calls.every(
          (c) => c.query['website_token'] == FakeChatServer.websiteToken,
        ),
        isTrue,
      );
      expect(errors, isEmpty);
      await client.loadMessages();
      expect(messages.map((m) => m.id), [1, 2]);
      await client.dispose();
    });

    // B1: validated trimmed, used untrimmed
    test('a base url with surrounding spaces works everywhere', () async {
      final client = await ZukkoChatClient.create(
        baseUrl: '  ${server.baseUrl}  ',
        websiteToken: FakeChatServer.websiteToken,
        enablePersistence: false,
        callbacks: ZukkoChatCallbacks(onError: errors.add),
      );

      expect(errors, isEmpty);
      expect(client.config?.websiteName, 'Zukko');
      await client.dispose();
    });

    // B2: a throwing host callback used to abort create()
    test('a throwing onError does not abort create()', () async {
      final saved = HiveDatabase.keyStore;
      HiveDatabase.keyStore = _BrokenKeyStore();
      addTearDown(() => HiveDatabase.keyStore = saved);

      final client = await ZukkoChatClient.create(
        baseUrl: server.baseUrl,
        websiteToken: FakeChatServer.websiteToken,
        callbacks: ZukkoChatCallbacks(onError: (_) => throw StateError('app')),
      );

      expect(client.config?.websiteName, 'Zukko');
      await client.dispose();
    });

    // P4
    test('two clients with the same key are independent; dispose of one '
        'leaves the other working', () async {
      final a = await create();
      final b = await create();
      // non-persisted clients do not share state: each got its own contact
      expect(server.contacts, hasLength(2));

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
      late ZukkoChatClient client;

      await runZonedGuarded(() async {
        client = await create();
        await pumpEventQueue();
      }, (e, _) => uncaught.add(e));

      expect(uncaught, isEmpty);
      expect(errors, isNotEmpty);
      expect(errors.first.type, isA<ZukkoChatExceptionType>());
      await client.dispose();
    });

    test('rejected identifier hash fails closed: onError, nothing else is '
        'requested, no websocket', () async {
      server.pubsubToken = 'would-connect';
      addTearDown(() {
        server.pubsubToken = null;
      });

      final client = await create(
        user: ZukkoChatUser(identifier: 'u', identifierHash: 'bad'),
      );

      expect(errors.map((e) => e.type), [
        ZukkoChatExceptionType.invalidIdentifierHash,
      ]);
      expect(server.requests, [
        'POST /api/v1/widget/config',
        'PATCH /api/v1/widget/contact/set_user',
      ]);
      await client.loadMessages();
      expect(errors.last.type, ZukkoChatExceptionType.invalidIdentifierHash);
      expect(server.to('/messages'), isEmpty);
      await client.dispose();
    });

    test('unreachable server: onError, no throw', () async {
      final client = await ZukkoChatClient.create(
        baseUrl: 'http://127.0.0.1:1',
        websiteToken: FakeChatServer.websiteToken,
        enablePersistence: false,
        callbacks: ZukkoChatCallbacks(onError: errors.add),
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
        ZukkoChatClient.create(
          baseUrl: 'http://chat.example.com',
          websiteToken: 'in',
          enablePersistence: false,
        ),
        throwsArgumentError,
      );
    });

    for (final url in ['ftp://chat.example.com', 'chat.example.com', '']) {
      test('"$url" is refused', () async {
        await expectLater(
          ZukkoChatClient.create(
            baseUrl: url,
            websiteToken: 'in',
            enablePersistence: false,
            allowInsecure: true,
          ),
          throwsArgumentError,
        );
      });
    }

    test('allowInsecure lets http to a non-loopback host through to the '
        'network layer', () async {
      final errors = <ZukkoChatException>[];

      final client = await ZukkoChatClient.create(
        baseUrl: 'http://nonexistent.invalid',
        websiteToken: 'in',
        enablePersistence: false,
        allowInsecure: true,
        callbacks: ZukkoChatCallbacks(onError: errors.add),
      );

      expect(errors, isNotEmpty); // unreachable, but it was attempted
      await client.dispose();
    });
  });

  // F14
  test('sendAction completes with false while not subscribed', () async {
    final client = await ZukkoChatClient.create(
      baseUrl: server.baseUrl,
      websiteToken: FakeChatServer.websiteToken,
      enablePersistence: false,
    );

    expect(
      await client.sendAction(ZukkoChatActionType.updatePresence),
      isFalse,
    );
    await client.dispose();
  });

  // F20
  group('storage failure', () {
    test('openDB failing: onError(STORAGE_FAILED) and the client works '
        'in memory', () async {
      final saved = HiveDatabase.keyStore;
      HiveDatabase.keyStore = _BrokenKeyStore();
      addTearDown(() => HiveDatabase.keyStore = saved);
      final errors = <ZukkoChatException>[];
      server.calls.clear();

      final client = await ZukkoChatClient.create(
        baseUrl: server.baseUrl,
        websiteToken: FakeChatServer.websiteToken,
        callbacks: ZukkoChatCallbacks(onError: errors.add),
      );

      expect(errors.map((e) => e.type), [ZukkoChatExceptionType.storageFailed]);
      expect(server.to('/config'), hasLength(1)); // still talks to the server
      await client.dispose();
    });
  });

  // SEC5 + SEC3 through create()
  group('identifier hash', () {
    final good = FakeChatServer.hashFor('u');
    Future<ZukkoChatClient> create(String? hash) => ZukkoChatClient.create(
      baseUrl: server.baseUrl,
      websiteToken: FakeChatServer.websiteToken,
      user: ZukkoChatUser(identifier: 'u', identifierHash: hash),
    );

    test('same identifier with another hash does not reuse the stored '
        'contact; the same hash does', () async {
      server.calls.clear();
      server.contacts.clear();
      int contacts() => server.contacts.length;

      await (await create(good)).dispose();
      await (await create(good)).dispose();
      expect(contacts(), 1);

      await (await create('hash-FORGED')).dispose();
      expect(contacts(), 2);
    });

    test('the hash is never written to disk', () async {
      final client = await create(good);

      // the SDK stores no user at all; the retired users box is not opened
      expect(Hive.isBoxOpen(ZukkoChatBoxNames.users), isFalse);
      await client.dispose();
    });

    test('clearData needs the same hash to find the instance', () async {
      await (await create(good)).dispose();
      final key = ZukkoChatClient.getClientInstanceKey(
        baseUrl: server.baseUrl,
        websiteToken: FakeChatServer.websiteToken,
        userIdentifier: 'u',
        identifierHash: good,
      );

      await ZukkoChatClient.clearData(
        baseUrl: server.baseUrl,
        websiteToken: FakeChatServer.websiteToken,
        userIdentifier: 'u',
        identifierHash: good,
      );

      expect(LocalStorage.persisted(key).contact.get(), isNull);
    });
  });

  group('persistence through the public API', () {
    late String key;

    setUp(() {
      key = ZukkoChatClient.getClientInstanceKey(
        baseUrl: 'https://a.example',
        websiteToken: FakeChatServer.websiteToken,
        userIdentifier: 'u1',
      );
    });

    Future<void> seed(String instanceKey) async {
      final s = LocalStorage.persisted(instanceKey);
      await s.contact.save(contact());
      await s.conversation.save(conversation());
      await s.messages.saveAllMessages([message(1), message(2)]);
    }

    void expectEmpty(String instanceKey) {
      final s = LocalStorage.persisted(instanceKey);
      expect(s.contact.get(), isNull);
      expect(s.conversation.get(), isNull);
      expect(s.messages.getMessages(), isEmpty);
    }

    // P1: used to build the key "" and so delete nothing
    test('clearData clears the target instance and only that one', () async {
      await env.open();
      final other = ZukkoChatClient.getClientInstanceKey(
        baseUrl: 'https://a.example',
        websiteToken: FakeChatServer.websiteToken,
        userIdentifier: 'u2',
      );
      await seed(key);
      await seed(other);

      await ZukkoChatClient.clearData(
        baseUrl: 'https://a.example',
        websiteToken: FakeChatServer.websiteToken,
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
      await ZukkoChatClient.clearData(
        baseUrl: 'https://a.example',
        websiteToken: FakeChatServer.websiteToken,
      );
    });

    test('clearAllData works before any box is open (fresh process)', () async {
      await ZukkoChatClient.clearAllData();
    });

    test('clearAllData removes every instance', () async {
      await env.open();
      await seed(key);
      await seed('another');

      await ZukkoChatClient.clearAllData();

      expectEmpty(key);
      expectEmpty('another');
    });

    // P3: second call used to hit a disposed container
    test('clearAllData can be called twice', () async {
      await ZukkoChatClient.clearAllData();
      await ZukkoChatClient.clearAllData();
    });

    test('clearData for a user-less instance (P10)', () async {
      await env.open();
      final anonymous = ZukkoChatClient.getClientInstanceKey(
        baseUrl: 'https://a.example',
        websiteToken: FakeChatServer.websiteToken,
      );
      await seed(anonymous);
      await seed(key);

      await ZukkoChatClient.clearData(
        baseUrl: 'https://a.example',
        websiteToken: FakeChatServer.websiteToken,
      );

      expectEmpty(anonymous);
      expect(LocalStorage.persisted(key).contact.get(), isNotNull);
    });

    test(
      'persisted clients with the same key reuse the stored contact and send '
      'its JWT',
      () async {
        server.calls.clear();
        server.contacts.clear();
        Future<ZukkoChatClient> create() => ZukkoChatClient.create(
          baseUrl: server.baseUrl,
          websiteToken: FakeChatServer.websiteToken,
        );

        await (await create()).dispose();
        await (await create()).dispose();

        expect(server.contacts, hasLength(1));
        final configs = server.to('/config');
        expect(configs.first.jwt, isEmpty);
        expect(configs.last.jwt, 'jwt-${server.contacts.keys.single}');
      },
    );
  });
}

class _BrokenKeyStore implements ZukkoChatKeyStore {
  @override
  Future<List<int>?> read() => throw StateError('keystore unavailable');

  @override
  Future<void> write(List<int> key) => throw StateError('keystore unavailable');
}
