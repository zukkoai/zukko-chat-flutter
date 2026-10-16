// ignore_for_file: library_private_types_in_public_api (test-local helper type)
import 'dart:async';

import 'package:zukko_chat_flutter/src/core/zukko_chat_callbacks.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/zukko_chat_repository.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_message.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_user.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_socket.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fakes.dart';
import '../utils/fixtures.dart';
import '../utils/scripted_widget.dart';

typedef T = ZukkoChatExceptionType;

final _t0 = DateTime(2026);

/// A repository on a scripted service (no session) with a fake websocket.
class _Plain {
  _Plain({void Function(ZukkoChatMessage)? onReceived}) {
    storage = LocalStorage.inMemory();
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
        onMessageReceived: onReceived,
      ),
    );
  }

  final service = FakeClientService();
  final hub = FakeSocketHub();
  final errors = <ZukkoChatException>[];
  late final LocalStorage storage;
  late final ZukkoChatRepositoryImpl repo;

  void subscribe() {
    storage.contact.save(contact(pubsubToken: 'tok'));
    repo.listenForEvents();
    hub.last.welcome();
    hub.last.confirm();
  }

  void reconnect(FakeAsync async) {
    hub.last.serverClose();
    async.flushMicrotasks();
    async.elapse(const Duration(seconds: 2)); // backoff 1 s + jitter
    hub.last.welcome();
    hub.last.confirm();
    async.flushMicrotasks();
  }
}

void plain(void Function(_Plain h, FakeAsync async) body) => fakeAsync((async) {
  final h = _Plain();
  body(h, async);
  h.repo.dispose();
  async.flushMicrotasks();
});

/// Repository + real session over a scripted server.
class _Live {
  _Live(this.async, {ZukkoChatUser? user}) {
    rig = WidgetRig(server, user: user, now: () => _t0.add(async.elapsed));
    repo = ZukkoChatRepositoryImpl(
      clientService: rig.service,
      localStorage: rig.storage,
      socket: ZukkoChatSocket(
        url: Uri.parse('wss://h/cable'),
        tokenProvider: () => rig.storage.contact.get()?.pubsubToken,
        connect: hub.connect,
      ),
      streamCallbacks: ZukkoChatCallbacks(
        onError: errors.add,
        onSessionReset: () => resets++,
      ),
      session: rig.session,
    );
  }

  final FakeAsync async;
  final server = ScriptedWidget();
  final hub = FakeSocketHub();
  final errors = <ZukkoChatException>[];
  int resets = 0;
  late final WidgetRig rig;
  late final ZukkoChatRepositoryImpl repo;

  void settle([Duration d = const Duration(milliseconds: 50)]) {
    async.elapse(d);
    async.flushMicrotasks();
  }

  /// Initialise, handshake and reject the subscription.
  void startAndReject() {
    unawaited(repo.initialize());
    settle();
    hub.last.welcome();
    hub.last.emit({'type': 'reject_subscription'});
    settle();
  }
}

void live(
  void Function(_Live h, FakeAsync async) body, {
  ZukkoChatUser? user,
}) => fakeAsync((async) {
  final h = _Live(async, user: user);
  body(h, async);
  h.repo.dispose();
  async.flushMicrotasks();
});

void main() {
  group('after-cursor comes from received messages only (3)', () {
    test('known {40}, own send returns 42, reconnect asks after=40', () {
      plain((h, async) {
        h.service.messagesResult = [message(40)];
        unawaited(h.repo.getMessages());
        async.flushMicrotasks();
        h.service.createMessageResult = message(42);
        unawaited(
          h.repo.sendMessage(
            ZukkoChatNewMessageRequest(content: 'x', echoId: 'e'),
          ),
        );
        async.flushMicrotasks();
        h.subscribe();
        async.flushMicrotasks();

        h.reconnect(async);

        expect(h.service.messageCursors.last.after, 40);
      });
    });

    test('a message event moves the cursor', () {
      plain((h, async) {
        h.storage.conversation.save(conversation(id: 8));
        h.subscribe();
        async.flushMicrotasks();
        h.hub.last.event('message.created', {
          'id': 50,
          'content': 'c',
          'created_at': 1626155918,
          'conversation_id': 8,
          'message_type': 1,
        });
        async.flushMicrotasks();

        h.reconnect(async);

        expect(h.service.messageCursors.last.after, 50);
      });
    });
  });

  group('the first subscription closes the startup gap (4)', () {
    test('no message known: the latest page', () {
      plain((h, async) {
        h.service.messagesResult = [message(1)];
        h.subscribe();
        async.flushMicrotasks();

        expect(h.service.messageCursors.single, (before: null, after: null));
      });
    });

    test('a known message: everything after it', () {
      plain((h, async) {
        h.service.messagesResult = [message(40)];
        unawaited(h.repo.getMessages());
        async.flushMicrotasks();
        h.subscribe();
        async.flushMicrotasks();

        expect(h.service.messageCursors.last.after, 40);
      });
    });
  });

  group('after paging (12)', () {
    List<ZukkoChatMessage> page(int from, int n) => [
      for (var i = 0; i < n; i++) message(from + i),
    ];

    test('a full page (100, the server cap) asks again from its newest id', () {
      plain((h, async) {
        h.service.messagePages = [page(1, 100), page(101, 3)];
        unawaited(h.repo.getMessages(after: 0));
        async.flushMicrotasks();

        expect(h.service.messageCursors.map((c) => c.after), [0, 100]);
        expect(h.storage.messages.getMessages(), hasLength(103));
      });
    });

    test('a server that never runs dry is cut at 20 pages', () {
      plain((h, async) {
        h.service.messagePages = [
          for (var p = 0; p < 40; p++) page(p * 100 + 1, 100),
        ];
        unawaited(h.repo.getMessages(after: 0));
        async.flushMicrotasks();

        expect(h.service.messageCursors, hasLength(20));
        expect(h.errors, isEmpty);
      });
    });

    test('the in-memory message index is capped at 2000: the oldest are '
        'forgotten', () {
      final received = <int>[];
      fakeAsync((async) {
        final h = _Plain(onReceived: (m) => received.add(m.id));
        unawaited(h.storage.conversation.save(conversation()));
        h.subscribe();
        for (final from in [1, 1501]) {
          h.service.messagePages = [
            for (var p = 0; p < 15; p++) page(from + p * 100, 100),
          ];
          unawaited(h.repo.getMessages(after: from - 1));
          async.flushMicrotasks();
        }
        // storage would still answer for them: only the index is under test
        unawaited(h.storage.messages.clear());
        async.flushMicrotasks();

        for (final id in [2500, 1]) {
          h.hub.last.event('message.created', {
            'id': id,
            'message_type': 1,
            'content': 'c',
            'created_at': 1626155918,
            'conversation_id': 7,
          });
          async.flushMicrotasks();
        }
        h.repo.dispose();
        async.flushMicrotasks();
      });
      // 2500 is still indexed (a repeat), 1 was evicted
      expect(received, [1]);
    });
  });

  group('markSeen is throttled (15)', () {
    test('a burst is one call now and one trailing call', () {
      plain((h, async) {
        for (var i = 0; i < 5; i++) {
          unawaited(h.repo.markSeen());
        }
        async.flushMicrotasks();
        expect(h.service.updateLastSeenCalls, 1);

        async.elapse(const Duration(seconds: 2));
        expect(h.service.updateLastSeenCalls, 2);

        async.elapse(const Duration(seconds: 10));
        expect(h.service.updateLastSeenCalls, 2);
      });
    });

    test('a single call has no trailing call; later ones go through', () {
      plain((h, async) {
        unawaited(h.repo.markSeen());
        async.elapse(const Duration(seconds: 3));
        expect(h.service.updateLastSeenCalls, 1);

        unawaited(h.repo.markSeen());
        async.flushMicrotasks();
        expect(h.service.updateLastSeenCalls, 2);
      });
    });
  });

  group('the socket follows the session (2)', () {
    test('first /config fails, a later send succeeds: the socket connects', () {
      live((h, async) {
        h.server.configStatus = 500;
        unawaited(h.repo.initialize());
        h.settle();
        expect(h.errors.single.type, T.getConfigFailed);
        expect(h.hub.channels, isEmpty); // no usable session, no socket

        h.server.configStatus = 200;
        async.elapse(const Duration(seconds: 5)); // past the start backoff
        unawaited(h.rig.service.getMessages());
        h.settle();

        expect(h.hub.channels, hasLength(1));
        expect(h.rig.storage.contact.get()!.pubsubToken, 'pub-1');
      });
    });

    test('a failed set_user keeps the socket closed until a retry works', () {
      live(user: ZukkoChatUser(identifier: 'u', identifierHash: 'h'), (
        h,
        async,
      ) {
        h.server.setUserStatus = 500;
        unawaited(h.repo.initialize());
        h.settle();
        expect(h.errors.single.type, T.identifyFailed);
        expect(h.hub.channels, isEmpty);

        h.server.setUserStatus = 200;
        async.elapse(const Duration(seconds: 5));
        unawaited(h.rig.service.getMessages());
        h.settle();

        expect(h.hub.channels, hasLength(1));
      });
    });

    test('a first start that adopts another contact resets once and connects '
        'once', () {
      live((h, async) {
        h.rig.storage.contact.save(contact(id: 5, authToken: 'jwt-5'));
        h.server.contactId = 9;
        unawaited(h.repo.initialize());
        h.settle();

        expect(h.resets, 1);
        expect(h.hub.channels, hasLength(1));
        expect(h.rig.storage.contact.get()!.id, 9);
      });
    });

    test(
      'a late start that adopts another contact resets and connects once',
      () {
        live((h, async) {
          h.rig.storage.contact.save(contact(id: 5, authToken: 'jwt-5'));
          h.server.configStatus = 500;
          unawaited(h.repo.initialize());
          h.settle();
          expect(h.hub.channels, isEmpty);

          h.server.configStatus = 200;
          h.server.contactId = 9;
          async.elapse(const Duration(seconds: 5));
          unawaited(h.rig.service.getMessages());
          h.settle();

          expect(h.resets, 1);
          expect(h.hub.channels, hasLength(1));
        });
      },
    );
  });

  group('a rejected subscription with the same token retries slowly (5)', () {
    test(
      '60 s, then 120 s, then 240 s; reported once; socket stays closed',
      () {
        live((h, async) {
          h.startAndReject();
          expect(h.server.count('/config'), 2); // start + the refresh
          expect(h.errors.map((e) => e.type), [T.socketSubscriptionRejected]);

          h.settle(const Duration(seconds: 30));
          expect(h.server.count('/config'), 2);
          h.settle(const Duration(seconds: 31));
          expect(h.server.count('/config'), 3);
          h.settle(const Duration(seconds: 100));
          expect(h.server.count('/config'), 3);
          h.settle(const Duration(seconds: 80));
          expect(h.server.count('/config'), 4);

          expect(h.hub.channels, hasLength(1));
          expect(h.errors, hasLength(1));
        });
      },
    );

    test('a new token at a retry reconnects', () {
      live((h, async) {
        h.startAndReject();
        h.server.pubsub = 'pub-2';

        h.settle(const Duration(seconds: 61));

        expect(h.hub.channels, hasLength(2));
      });
    });

    test('resume retries at once', () {
      live((h, async) {
        h.startAndReject();
        h.server.pubsub = 'pub-2';

        h.repo.resume();
        h.settle();

        expect(h.hub.channels, hasLength(2));
      });
    });

    test('dispose stops the retries', () {
      live((h, async) {
        h.startAndReject();
        unawaited(h.repo.dispose());

        h.settle(const Duration(minutes: 30));

        expect(h.server.count('/config'), 2);
      });
    });

    test('fail-closed (hash rejected) stops the retries', () {
      live(user: ZukkoChatUser(identifier: 'u', identifierHash: 'h'), (
        h,
        async,
      ) {
        h.startAndReject();
        h.server.setUserStatus = 401;

        h.settle(const Duration(seconds: 61)); // the retry hits the 401
        final configs = h.server.count('/config');
        h.settle(const Duration(minutes: 30));

        expect(h.rig.session.failure?.type, T.invalidIdentifierHash);
        expect(h.server.count('/config'), configs);
      });
    });
  });
}
