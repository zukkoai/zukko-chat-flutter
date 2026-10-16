import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_chat_server.dart';

/// The whole stack (session, interceptor, REST, multipart, ActionCable
/// socket, repository) against the loopback server, which mirrors the real
/// Widget API wire format (see fake_chat_server.dart).
void main() {
  late FakeChatServer server;

  setUpAll(() async => server = await FakeChatServer.start());
  tearDownAll(() => server.close());

  setUp(() {
    server
      ..reset()
      ..calls.clear()
      ..subscribeIdentifiers.clear()
      ..pingsSent = 0
      ..presenceUpdates = 0
      ..forceStatus = null
      ..hasConversation = false
      ..messageIds = []
      ..privateIds.clear()
      ..activityIds.clear()
      ..createdJoinsList = false
      ..createdId = 100
      ..hmacMandatory = false
      ..cableToken = null
      ..pingEvery = const Duration(seconds: 3)
      ..pubsubToken = 'pubsub-1';
  });

  Future<void> until(bool Function() done, {int seconds = 8}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('condition not met in time');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// A connected client with the callbacks recorded into the lists.
  Future<ZukkoChatClient> connect({
    required List<ZukkoChatException> errors,
    List<ZukkoChatMessage>? retrieved,
    List<int>? subscribed,
    List<int>? sent,
    ZukkoChatUser? user,
    Duration? subscribeTimeout,
  }) async {
    final client = await ZukkoChatClient.create(
      baseUrl: server.baseUrl,
      websiteToken: FakeChatServer.websiteToken,
      user: user,
      enablePersistence: false,
      socketSubscribeTimeout: subscribeTimeout,
      callbacks: ZukkoChatCallbacks(
        onError: errors.add,
        onConfirmedSubscription: () => subscribed?.add((subscribed.length) + 1),
        onMessageSent: (m, _) => sent?.add(m.id),
        onMessagesRetrieved: (list) => retrieved?.addAll(list),
      ),
    );
    addTearDown(client.dispose);
    return client;
  }

  test('identify, chat, send text and a file, reconnect fetches only what is '
      'new', () async {
    server
      ..createdJoinsList = true
      ..createdId = 3;
    final errors = <ZukkoChatException>[];
    final subscribed = <int>[];
    final sent = <int>[];
    final retrieved = <ZukkoChatMessage>[];

    final client = await connect(
      errors: errors,
      subscribed: subscribed,
      sent: sent,
      retrieved: retrieved,
      user: ZukkoChatUser(
        identifier: 'u1',
        identifierHash: FakeChatServer.hashFor('u1'),
        name: 'Ali',
      ),
    );

    // session first, then the conversation, then realtime
    expect(server.requests.take(4), [
      'POST /api/v1/widget/config',
      'PATCH /api/v1/widget/contact/set_user',
      'GET /api/v1/widget/contact',
      'GET /api/v1/widget/conversations',
    ]);
    expect(client.config?.websiteName, 'Zukko');
    await until(() => subscribed.isNotEmpty);
    expect(server.subscribeIdentifiers.single, contains('pubsub-1'));

    // text, then one file: the first message creates the conversation
    await client.sendMessage(content: 'hello', echoId: 'e1');
    server.createdId = 4;
    await client.sendMessage(
      content: '',
      echoId: 'e2',
      attachments: [
        ZukkoChatUpload.bytes(
          name: 'note.txt',
          bytes: Uint8List.fromList('FILE-BYTES'.codeUnits),
        ),
      ],
    );
    expect(sent, [3, 4]);
    final posts = server.calls.where(
      (c) => c.method == 'POST' && c.path.endsWith('/messages'),
    );
    expect(posts, hasLength(2));
    // the fake only accepted the file because the field was message[...]
    final file = posts.last.parts.singleWhere((p) => p.filename != null);
    expect(file.name, 'message[attachments][]');
    expect(file.text, 'FILE-BYTES');
    expect(posts.every((c) => c.jwt == 'jwt-1'), isTrue);
    expect(errors, isEmpty);

    // the connection drops while an agent writes message 5; the server
    // sends created_at as unix seconds (an int), the SDK turns it into a date
    server.messageIds.add(5);
    retrieved.clear();
    await server.sockets.single.close();
    await until(() => subscribed.length == 2);
    await until(() => retrieved.isNotEmpty);

    // Sent messages are not the fetch cursor (only server-fed ones are), so
    // this reconnect re-fetches the latest page; the merge is by id.
    expect([for (final m in retrieved) m.id], [3, 4, 5]);
    expect(
      DateTime.parse(retrieved.last.createdAt),
      DateTime.fromMillisecondsSinceEpoch(1700000005 * 1000, isUtc: true),
    );
    expect(server.to('/messages').last.query.containsKey('after'), isFalse);
    expect(errors, isEmpty);
  });

  test('a long outage: more than 100 missed messages are all fetched, in '
      'order', () async {
    server
      ..hasConversation = true
      ..messageIds = [1, 2];
    final errors = <ZukkoChatException>[];
    final subscribed = <int>[];
    final retrieved = <ZukkoChatMessage>[];
    await connect(errors: errors, subscribed: subscribed, retrieved: retrieved);
    await until(() => subscribed.isNotEmpty);
    await until(() => retrieved.isNotEmpty); // the cursor is now 2

    // the server caps `after` pages at 100 (message_finder.rb:32)
    server.messageIds = [for (var i = 1; i <= 250; i++) i];
    await server.sockets.single.close();
    Set<int> missed() => {
      for (final m in retrieved)
        if (m.id > 2) m.id,
    };
    await until(() => missed().length == 248);

    expect(missed().toList()..sort(), [for (var i = 3; i <= 250; i++) i]);
    expect(
      server
          .to('/messages')
          .map((c) => c.query['after'])
          .toList()
          .sublist(server.to('/messages').length - 3),
      ['2', '102', '202'],
    );
    expect(errors, isEmpty);
  });

  test('private notes and activity messages are not served', () async {
    server
      ..hasConversation = true
      ..messageIds = [1, 2, 3, 4]
      ..privateIds.add(2)
      ..activityIds.add(3);
    final errors = <ZukkoChatException>[];
    final retrieved = <ZukkoChatMessage>[];
    await connect(errors: errors, retrieved: retrieved);
    await until(() => retrieved.isNotEmpty);

    expect([for (final m in retrieved) m.id], [1, 4]);
  });

  group('multipart contract', () {
    late Dio dio;

    setUp(() {
      final id = server.addContact();
      dio = Dio(
        BaseOptions(
          baseUrl: '${server.baseUrl}/api/v1/widget',
          queryParameters: {'website_token': FakeChatServer.websiteToken},
          headers: {'X-Auth-Token': 'jwt-$id'},
          validateStatus: (_) => true,
        ),
      );
    });

    MultipartFile file(String name, [String? type]) => MultipartFile.fromBytes(
      'x'.codeUnits,
      filename: name,
      contentType: type == null ? null : DioMediaType.parse(type),
    );

    Future<int?> post(FormData form) async =>
        (await dio.post<Object?>('/messages', data: form)).statusCode;

    test('message[attachments][] is accepted', () async {
      final form = FormData()
        ..fields.add(const MapEntry('message[content]', 'hi'))
        ..files.add(MapEntry('message[attachments][]', file('a.txt')));
      expect(await post(form), 200);
    });

    test('a file outside the message[...] nesting is ignored: nothing to '
        'send, 422', () async {
      final form = FormData()
        ..fields.add(const MapEntry('message[echo_id]', 'e'))
        ..files.add(MapEntry('attachments[]', file('a.txt')));
      expect(await post(form), 422);
    });

    test('no message hash at all: the server errors (500)', () async {
      final form = FormData()..files.add(MapEntry('file', file('a.txt')));
      expect(await post(form), 500);
    });

    test('blank JSON content: 422; missing message key: 500', () async {
      expect(
        (await dio.post<Object?>(
          '/messages',
          data: {
            'message': {'content': ''},
          },
        )).statusCode,
        422,
      );
      expect(
        (await dio.post<Object?>(
          '/messages',
          data: {'content': 'x'},
        )).statusCode,
        500,
      );
    });

    test('unsupported type is 422, images are fine', () async {
      Future<int?> withFile(String name, String type) => post(
        FormData()
          ..files.add(MapEntry('message[attachments][]', file(name, type))),
      );
      expect(await withFile('a.exe', 'application/x-msdownload'), 422);
      expect(await withFile('a.png', 'image/png'), 200);
    });
  });

  group('identifier hash', () {
    test('a wrong hash fails closed with a typed error', () async {
      final errors = <ZukkoChatException>[];
      await connect(
        errors: errors,
        user: ZukkoChatUser(identifier: 'u1', identifierHash: 'bad'),
      );
      expect(errors.map((e) => e.type), [
        ZukkoChatExceptionType.invalidIdentifierHash,
      ]);
    });

    test('inbox with hmac_mandatory and no hash: the debug log gets exactly '
        'one line, the ERROR', () async {
      server.hmacMandatory = true;
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
      addTearDown(() => debugPrint = previous);
      final errors = <ZukkoChatException>[];
      await connect(
        errors: errors,
        user: ZukkoChatUser(identifier: 'u1'),
      );
      expect(
        errors.map((e) => e.type),
        contains(ZukkoChatExceptionType.invalidIdentifierHash),
      );
      expect(logs, hasLength(1));
      expect(logs.single, startsWith('[zukko_chat] ERROR: '));
      expect(logs.single, contains('identifierHash is missing'));
    });

    test('inbox with hmac_mandatory: no hash is rejected, the right one '
        'passes', () async {
      server.hmacMandatory = true;
      final errors = <ZukkoChatException>[];
      await connect(
        errors: errors,
        user: ZukkoChatUser(identifier: 'u1'),
      );
      expect(
        errors.map((e) => e.type),
        contains(ZukkoChatExceptionType.invalidIdentifierHash),
      );

      final ok = <ZukkoChatException>[];
      await connect(
        errors: ok,
        user: ZukkoChatUser(
          identifier: 'u2',
          identifierHash: FakeChatServer.hashFor('u2'),
        ),
      );
      expect(ok, isEmpty);
    });
  });

  group('realtime', () {
    test('ping frames keep an otherwise silent socket alive past the stale '
        'watchdog', () async {
      server.pingEvery = const Duration(seconds: 1);
      final errors = <ZukkoChatException>[];
      final subscribed = <int>[];
      await connect(errors: errors, subscribed: subscribed);
      await until(() => subscribed.isNotEmpty);

      // the SDK drops a socket that is silent for 6 s
      await Future<void>.delayed(const Duration(seconds: 8));

      expect(server.pingsSent, greaterThanOrEqualTo(6));
      expect(server.subscribeIdentifiers, hasLength(1)); // never reconnected
      expect(subscribed, hasLength(1));
      expect(errors, isEmpty);
    });

    test('an unknown pubsub token is never confirmed: the SDK gives up '
        'with SOCKET_SUBSCRIPTION_REJECTED', () async {
      server.cableToken = 'someone-elses';
      final errors = <ZukkoChatException>[];
      final subscribed = <int>[];
      await connect(
        errors: errors,
        subscribed: subscribed,
        subscribeTimeout: const Duration(milliseconds: 200),
      );

      await until(
        () => errors.any(
          (e) => e.type == ZukkoChatExceptionType.socketSubscriptionRejected,
        ),
        seconds: 10,
      );

      expect(subscribed, isEmpty);
      expect(server.subscribeIdentifiers, hasLength(2)); // one retry
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  test('the latest page is 20 messages; before= pages back, 20 at a time, '
      'until a short page', () async {
    server
      ..hasConversation = true
      ..messageIds = [for (var i = 1; i <= 50; i++) i];
    final errors = <ZukkoChatException>[];
    final retrieved = <ZukkoChatMessage>[];
    final client = await connect(errors: errors, retrieved: retrieved);

    await client.loadMessages();
    expect(retrieved.map((m) => m.id), [for (var i = 31; i <= 50; i++) i]);

    final p2 = await client.loadOlderMessages(before: 31);
    expect(p2!.map((m) => m.id), [for (var i = 11; i <= 30; i++) i]);

    final p3 = await client.loadOlderMessages(before: 11);
    expect(p3!.map((m) => m.id), [for (var i = 1; i <= 10; i++) i]);
    expect(errors, isEmpty);
  });
}
