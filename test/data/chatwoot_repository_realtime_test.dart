import 'dart:async';

import 'package:chatwoot_sdk/src/core/chatwoot_callbacks.dart';
import 'package:chatwoot_sdk/src/core/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/src/data/chatwoot_repository.dart';
import 'package:chatwoot_sdk/src/data/local/dao/chatwoot_messages_dao.dart';
import 'package:chatwoot_sdk/src/data/local/dao/single_store.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_message.dart';
import 'package:chatwoot_sdk/src/data/remote/api/requests/chatwoot_new_message_request.dart';
import 'package:chatwoot_sdk/src/data/remote/realtime/chatwoot_action_data.dart';
import 'package:chatwoot_sdk/src/data/remote/realtime/chatwoot_socket.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fakes.dart';
import '../utils/fixtures.dart';

/// Repository + a REAL [ChatwootSocket] over [FakeChannel]s, under fake time:
/// frames in, callbacks out.
class _Harness {
  _Harness(this.async, {LocalStorage? store})
    : storage = store ?? LocalStorage.inMemory() {
    socket = ChatwootSocket(
      url: Uri.parse('wss://h/cable'),
      tokenProvider: () => storage.contact.get()?.pubsubToken,
      connect: hub.connect,
      backoff: (_) => const Duration(seconds: 1),
    );
    repo = ChatwootRepositoryImpl(
      clientService: service,
      localStorage: storage,
      socket: socket,
      streamCallbacks: ChatwootCallbacks(
        onError: errors.add,
        onMessagesRetrieved: (m) => log.add('retrieved ${m.map((e) => e.id)}'),
        onMessageDelivered: (m, echo) => delivered.add((m, echo)),
        onMessageReceived: received.add,
        onMessageUpdated: updated.add,
        onWelcome: () => log.add('welcome'),
        onPing: () => pings++,
        onConfirmedSubscription: () => log.add('confirmed'),
        onConversationStartedTyping: () => log.add('typing_on'),
        onConversationStoppedTyping: () => log.add('typing_off'),
        onConversationIsOnline: () => log.add('online'),
        onConversationIsOffline: () => log.add('offline'),
        onConversationResolved: () => log.add('resolved'),
        onConnectionStateChanged: (s) => states.add(s),
      ),
    );
  }

  final FakeAsync async;
  final service = FakeClientService();
  final LocalStorage storage;
  final hub = FakeSocketHub();
  late final ChatwootSocket socket;
  late final ChatwootRepositoryImpl repo;

  final errors = <ChatwootClientException>[];
  final received = <ChatwootMessage>[];
  final updated = <ChatwootMessage>[];
  final delivered = <(ChatwootMessage, String)>[];
  final log = <String>[];
  var pings = 0;
  final states = <ChatwootConnectionState>[];

  FakeChannel get channel => hub.last;

  void flush() => async.flushMicrotasks();
  void elapse(Duration d) {
    async.elapse(d);
    flush();
  }

  /// Contact with token stored, listening, handshake completed.
  void subscribe({int conversationId = 8}) {
    storage.contact.save(contact(pubsubToken: 'tok'));
    storage.conversation.save(conversation(id: conversationId));
    flush();
    repo.listenForEvents();
    channel.welcome();
    channel.confirm();
    flush();
    log.clear();
  }

  void keepAlive(Duration total) {
    for (var t = 0; t < total.inSeconds; t += 3) {
      elapse(const Duration(seconds: 3));
      channel.ping();
    }
    flush();
  }

  void messageCreated(Map<String, Object?> data) {
    channel.event('message.created', {
      'content': 'c',
      'created_at': 1626155918,
      'conversation_id': 8,
      ...data,
    });
    flush();
  }
}

// ignore: library_private_types_in_public_api (test-local helper type)
void run(void Function(_Harness h) body, {LocalStorage? storage}) =>
    fakeAsync((async) {
      final h = _Harness(async, store: storage);
      body(h);
      h.repo.dispose();
      async.flushMicrotasks();
    });

void main() {
  group('lifecycle callbacks', () {
    test('welcome, ping, confirm and connection states are reported', () {
      run((h) {
        h.storage.contact.save(contact(pubsubToken: 'tok'));
        h.flush();
        h.repo.listenForEvents();
        h.channel.welcome();
        h.channel.ping();
        h.channel.confirm();
        h.flush();

        expect(h.log, ['welcome', 'confirmed']);
        expect(h.pings, 1);
        expect(h.states, [
          ChatwootConnectionState.connecting,
          ChatwootConnectionState.connected,
          ChatwootConnectionState.subscribed,
        ]);
        expect(h.channel.presenceFrames, 1);
      });
    });

    test('without a pubsub token nothing connects', () {
      run((h) {
        h.repo.listenForEvents();

        expect(h.hub.channels, isEmpty);
      });
    });
  });

  group('listenForEvents is idempotent (S2)', () {
    test('called twice: the first channel is closed, events arrive once', () {
      run((h) {
        h.subscribe();
        final first = h.channel;
        h.repo.listenForEvents();
        h.channel.welcome();
        h.channel.confirm();
        h.flush();

        h.messageCreated({'id': 4, 'message_type': 1});

        expect(first.closeCodeByClient, 1000);
        expect(h.received.map((m) => m.id), [4]);
        expect(h.storage.messages.getMessages(), hasLength(1));
      });
    });

    test('sending a message never opens another socket', () {
      run((h) {
        h.storage.contact.save(contact(pubsubToken: 'tok'));
        h.flush();
        h.repo.listenForEvents(); // not yet confirmed
        h.service.createMessageResult = message(5);

        h.repo.sendMessage(
          ChatwootNewMessageRequest(content: 'x', echoId: 'e'),
        );
        h.flush();

        expect(h.hub.channels, hasLength(1));
      });
    });
  });

  group('message.created', () {
    test('own message with its echo id is delivered, not received', () {
      run((h) {
        h.subscribe();

        h.messageCreated({'id': 3, 'message_type': 0, 'echo_id': 'echo-9'});

        expect(h.delivered.single.$2, 'echo-9');
        expect(h.received, isEmpty);
        expect(h.storage.messages.getMessage(3), isNotNull);
      });
    });

    // S4: used to be `echoId!`
    test('own message without echo id (other device): received, no crash', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        run((h) {
          h.subscribe();

          h.messageCreated({'id': 3, 'message_type': 0});

          expect(h.received.map((m) => m.id), [3]);
          expect(h.delivered, isEmpty);
        });
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
    });

    test('an agent message is received once, even if the frame repeats', () {
      run((h) {
        h.subscribe();

        h.messageCreated({'id': 4, 'message_type': 1});
        h.messageCreated({'id': 4, 'message_type': 1});

        expect(h.received.map((m) => m.id), [4]);
      });
    });

    test('activity messages and private notes are skipped (S14)', () {
      run((h) {
        h.subscribe();

        h.messageCreated({'id': 5, 'message_type': 2});
        h.messageCreated({'id': 6, 'message_type': 1, 'private': true});

        expect(h.received, isEmpty);
        expect(h.delivered, isEmpty);
        expect(h.storage.messages.getMessages(), isEmpty);
      });
    });

    test('template messages (type 3) are received', () {
      run((h) {
        h.subscribe();

        h.messageCreated({'id': 7, 'message_type': 3});

        expect(h.received.map((m) => m.id), [7]);
      });
    });

    test('message.updated is stored and reported', () {
      run((h) {
        h.subscribe();

        h.channel.event('message.updated', {
          'id': 111,
          'content': 'edited',
          'conversation_id': 8,
          'message_type': 1,
        });
        h.flush();

        expect(h.updated.single.content, 'edited');
        expect(h.storage.messages.getMessage(111), isNotNull);
      });
    });
  });

  group('malformed frames (S3, S6)', () {
    test('frames missing data never throw; later frames still work', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        run((h) {
          h.subscribe();

          h.channel.event('presence.update', {});
          h.channel.event('presence.update', {'users': <Object>[]});
          h.channel.emit({
            'message': {'event': 'message.created'},
          });
          h.channel.emit({
            'message': {'event': 'message.updated', 'data': <Object>[]},
          });
          h.channel.event('message.created', {'id': 'not-a-number'});
          h.flush();
          expect(h.log, isEmpty);
          expect(h.received, isEmpty);

          h.messageCreated({'id': 9, 'message_type': 1});
          expect(h.received.map((m) => m.id), [9]);
        });
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
    });

    test('a callback that throws does not stop later events', () {
      fakeAsync((async) {
        final h = _Harness(async);
        final seen = <int>[];
        final repo = ChatwootRepositoryImpl(
          clientService: h.service,
          localStorage: h.storage,
          socket: h.socket,
          streamCallbacks: ChatwootCallbacks(
            onMessageReceived: (m) {
              seen.add(m.id);
              if (m.id == 1) throw StateError('app bug');
            },
          ),
        );
        h.storage.contact.save(contact(pubsubToken: 'tok'));
        h.storage.conversation.save(conversation(id: 8));
        h.flush();
        repo.listenForEvents();
        h.channel.welcome();
        h.channel.confirm();
        h.messageCreated({'id': 1, 'message_type': 1});
        h.messageCreated({'id': 2, 'message_type': 1});

        expect(seen, [1, 2]);
        repo.dispose();
        h.flush();
      });
    });
  });

  group('rejected subscription (S5)', () {
    test('reports SOCKET_SUBSCRIPTION_REJECTED, no presence, no reconnect', () {
      run((h) {
        h.storage.contact.save(contact(pubsubToken: 'stale'));
        h.flush();
        h.repo.listenForEvents();
        h.channel.welcome();
        h.channel.emit({'type': 'reject_subscription'});
        h.flush();
        h.elapse(const Duration(minutes: 2));

        expect(
          h.errors.single.type,
          ChatwootClientExceptionType.SOCKET_SUBSCRIPTION_REJECTED,
        );
        expect(h.channel.presenceFrames, 0);
        expect(h.hub.channels, hasLength(1));
        expect(h.states.last, ChatwootConnectionState.closed);
      });
    });
  });

  group('refetch after reconnect (S11)', () {
    test(
      'the first subscription does not refetch; each reconnect does once',
      () {
        run((h) {
          h.service.messagesResult = [message(1), message(2)];
          h.subscribe();
          expect(h.service.getAllMessagesCalls, 0);

          for (var reconnect = 1; reconnect <= 2; reconnect++) {
            h.channel.serverClose();
            h.flush();
            h.elapse(const Duration(seconds: 1));
            h.channel.welcome();
            h.channel.confirm();
            h.flush();

            expect(h.service.getAllMessagesCalls, reconnect);
          }
          expect(h.log.where((l) => l.startsWith('retrieved')), hasLength(2));
          expect(h.storage.messages.getMessages().map((m) => m.id), [1, 2]);
        });
      },
    );

    test('a refetch failure is reported, not thrown', () {
      run((h) {
        h.service.messagesResult = failure(
          ChatwootClientExceptionType.GET_MESSAGES_FAILED,
        );
        h.subscribe();

        h.channel.serverClose();
        h.flush();
        h.elapse(const Duration(seconds: 1));
        h.channel.welcome();
        h.channel.confirm();
        h.flush();

        expect(
          h.errors.single.type,
          ChatwootClientExceptionType.GET_MESSAGES_FAILED,
        );
      });
    });

    test('the connection state callback sees the drop and the recovery', () {
      run((h) {
        h.subscribe();
        h.states.clear();

        h.channel.serverClose();
        h.flush();
        h.elapse(const Duration(seconds: 1));
        h.channel.welcome();
        h.channel.confirm();
        h.flush();

        expect(h.states, [
          ChatwootConnectionState.backoff,
          ChatwootConnectionState.connecting,
          ChatwootConnectionState.connected,
          ChatwootConnectionState.subscribed,
        ]);
      });
    });
  });

  group('typing (S12)', () {
    test('typing_on clears itself after 30 s, exactly once', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_on', {});
        h.keepAlive(const Duration(seconds: 27));
        expect(h.log, ['typing_on']);
        h.keepAlive(const Duration(seconds: 6));

        expect(h.log, ['typing_on', 'typing_off']);
        h.keepAlive(const Duration(seconds: 60));
        expect(h.log, ['typing_on', 'typing_off']);
      });
    });

    test('typing_off cancels the timer: exactly one stop', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_on', {});
        h.keepAlive(const Duration(seconds: 6));
        h.channel.event('conversation.typing_off', {});
        h.keepAlive(const Duration(seconds: 60));

        expect(h.log, ['typing_on', 'typing_off']);
      });
    });

    test('another typing_on restarts the 30 s window', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_on', {});
        h.keepAlive(const Duration(seconds: 21));
        h.channel.event('conversation.typing_on', {});
        h.keepAlive(const Duration(seconds: 21)); // 42 s since the first
        expect(h.log, ['typing_on']);
        h.keepAlive(const Duration(seconds: 12));

        expect(h.log, ['typing_on', 'typing_off']);
      });
    });

    test('private typing is ignored', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_on', {'is_private': true});
        h.keepAlive(const Duration(seconds: 40));

        expect(h.log, isEmpty);
      });
    });

    test('an agent message ends the typing indicator', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_on', {});
        h.messageCreated({'id': 1, 'message_type': 1});

        expect(h.log, ['typing_on', 'typing_off']);
      });
    });

    test('losing the connection clears the typing indicator', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_on', {});
        h.channel.serverClose();
        h.flush();

        expect(h.log, ['typing_on', 'typing_off']);
      });
    });
  });

  group('presence (S13)', () {
    void presence(_Harness h, Map<String, Object?> users) {
      h.channel.event('presence.update', {'users': users});
      h.flush();
    }

    test('online, then offline once after 40 s', () {
      run((h) {
        h.subscribe();

        presence(h, {'1': 'online'});
        h.keepAlive(const Duration(seconds: 39));
        expect(h.log, ['online']);
        h.keepAlive(const Duration(seconds: 3));
        h.keepAlive(const Duration(seconds: 60));

        expect(h.log, ['online', 'offline']);
      });
    });

    test('every update restarts the 40 s window', () {
      run((h) {
        h.subscribe();

        presence(h, {'1': 'online'});
        h.keepAlive(const Duration(seconds: 30));
        presence(h, {'1': 'online'});
        h.keepAlive(const Duration(seconds: 30)); // 60 s since the first
        expect(h.log, ['online', 'online']);
        h.keepAlive(const Duration(seconds: 12));

        expect(h.log, ['online', 'online', 'offline']);
      });
    });

    test('an empty agent list is offline immediately', () {
      run((h) {
        h.subscribe();

        presence(h, {});

        expect(h.log, ['offline']);
      });
    });

    test('agents that are not online are offline', () {
      run((h) {
        h.subscribe();

        presence(h, {'1': 'busy'});

        expect(h.log, ['offline']);
      });
    });

    test('the reset timer is cancelled when the connection drops', () {
      run((h) {
        h.subscribe();
        presence(h, {'1': 'online'});

        h.channel.serverClose();
        h.flush();
        h.elapse(const Duration(seconds: 120));

        expect(h.log, ['online']);
      });
    });
  });

  group('conversation resolved', () {
    test('clears the open conversation and its messages', () {
      run((h) {
        h.subscribe(conversationId: 8);
        h.storage.messages.saveMessage(message(1));
        h.flush();

        h.channel.event('conversation.status_changed', {
          'id': 8,
          'status': 'resolved',
        });
        h.flush();

        expect(h.log, ['resolved']);
        expect(h.storage.conversation.get(), isNull);
        expect(h.storage.messages.getMessages(), isEmpty);
      });
    });

    test('another conversation resolving is ignored', () {
      run((h) {
        h.subscribe(conversationId: 8);

        h.channel.event('conversation.status_changed', {
          'id': 99,
          'status': 'resolved',
        });
        h.flush();

        expect(h.log, isEmpty);
        expect(h.storage.conversation.get(), isNotNull);
      });
    });
  });

  group('sendAction (S17)', () {
    test('writes the frame when subscribed', () {
      run((h) {
        h.subscribe();
        final before = h.channel.sent.length;

        h.repo.sendAction(ChatwootActionType.update_presence);

        expect(h.channel.sent.length, before + 1);
      });
    });

    test('is a silent no-op without a connection', () {
      run((h) {
        expect(
          () => h.repo.sendAction(ChatwootActionType.update_presence),
          returnsNormally,
        );
      });
    });
  });

  group('dispose (S8)', () {
    test(
      'closes the socket; late frames reach neither callbacks nor storage',
      () {
        run((h) {
          h.subscribe();
          final channel = h.channel;

          h.repo.dispose();
          h.flush();
          channel.event('message.created', {
            'id': 1,
            'message_type': 1,
            'created_at': 1,
            'content': 'late',
          });
          h.flush();
          h.elapse(const Duration(minutes: 5));

          expect(channel.closeCodeByClient, 1000);
          expect(h.received, isEmpty);
          expect(h.storage.messages.getMessages(), isEmpty);
          expect(h.hub.channels, hasLength(1));
        });
      },
    );

    test('pending typing / presence timers do not fire afterwards', () {
      run((h) {
        h.subscribe();
        h.channel.event('conversation.typing_on', {});
        h.channel.event('presence.update', {
          'users': {'1': 'online'},
        });
        h.flush();
        h.log.clear();

        h.repo.dispose();
        h.elapse(const Duration(minutes: 5));

        expect(h.log, isEmpty);
      });
    });

    test('twice is fine; listenForEvents afterwards does nothing', () {
      run((h) {
        h.subscribe();

        h.repo.dispose();
        h.repo.dispose();
        h.repo.listenForEvents();

        expect(h.hub.channels, hasLength(1));
      });
    });
  });

  group('logging (S15)', () {
    test('frames are never printed', () {
      final printed = <String>[];
      runZoned(
        () {
          run((h) {
            h.subscribe();
            h.channel.emit('garbage');
            h.messageCreated({'id': 1, 'message_type': 1, 'content': 'secret'});
          });
        },
        zoneSpecification: ZoneSpecification(
          print: (s, p, z, line) {
            printed.add(line);
          },
        ),
      );

      expect(printed.where((l) => l.contains('secret')), isEmpty);
    });
  });

  // F19: Hive's put is not awaited on the live path, so getMessage lags
  group('duplicate frames in the same tick (F19)', () {
    test('two identical message.created frames report once, even when '
        'storage is slow', () {
      final slow = _SlowDao();
      run(
        (h) {
          h.subscribe();

          h.channel.event('message.created', {
            'id': 7,
            'content': 'c',
            'created_at': 1626155918,
            'conversation_id': 8,
            'message_type': 1,
          });
          h.channel.event('message.created', {
            'id': 7,
            'content': 'c',
            'created_at': 1626155918,
            'conversation_id': 8,
            'message_type': 1,
          });
          h.flush();

          expect(h.received.map((m) => m.id), [7]);
          expect(slow.saved, 2); // both writes were issued, nothing lost
        },
        storage: LocalStorage(
          contact: MemorySingleStore(),
          conversation: MemorySingleStore(),
          user: MemorySingleStore(),
          messages: slow,
        ),
      );
    });
  });

  // SEC8
  group('events must belong to the open conversation', () {
    test('message.created for another conversation is dropped', () {
      run((h) {
        h.subscribe(conversationId: 8);

        h.messageCreated({'id': 1, 'message_type': 1, 'conversation_id': 99});
        h.channel.event('message.created', {'id': 2, 'message_type': 1});
        h.flush();

        expect(h.received, isEmpty);
        expect(h.storage.messages.getMessages(), isEmpty);
      });
    });

    test('message.updated for another conversation does not overwrite', () {
      run((h) {
        h.subscribe(conversationId: 8);
        h.messageCreated({'id': 1, 'message_type': 1, 'content': 'orig'});

        h.channel.event('message.updated', {
          'id': 1,
          'content': 'forged',
          'conversation_id': 99,
          'message_type': 1,
        });
        h.flush();

        expect(h.updated, isEmpty);
        expect(h.storage.messages.getMessage(1)!.content, 'orig');
      });
    });

    test('an update cannot flip messageType (agent -> contact)', () {
      run((h) {
        h.subscribe();
        h.messageCreated({'id': 1, 'message_type': 1, 'content': 'orig'});

        h.channel.event('message.updated', {
          'id': 1,
          'content': 'forged',
          'conversation_id': 8,
          'message_type': 0,
        });
        h.flush();

        expect(h.updated, isEmpty);
        expect(h.storage.messages.getMessage(1)!.messageType, 1);
      });
    });

    test('an update cannot change the sender', () {
      run((h) {
        h.subscribe();
        h.messageCreated({
          'id': 1,
          'message_type': 1,
          'sender': {'id': 5, 'name': 'agent'},
        });

        h.channel.event('message.updated', {
          'id': 1,
          'content': 'forged',
          'conversation_id': 8,
          'message_type': 1,
          'sender': {'id': 6, 'name': 'someone else'},
        });
        h.flush();

        expect(h.updated, isEmpty);
      });
    });

    test('a legitimate edit still goes through', () {
      run((h) {
        h.subscribe();
        h.messageCreated({
          'id': 1,
          'message_type': 1,
          'sender': {'id': 5, 'name': 'agent'},
        });

        h.channel.event('message.updated', {
          'id': 1,
          'content': 'edited',
          'conversation_id': 8,
          'message_type': 1,
          'sender': {'id': 5, 'name': 'agent renamed'},
        });
        h.flush();

        expect(h.updated.single.content, 'edited');
      });
    });
  });

  // F3
  group('session reset (F3)', () {
    test('after the session was reset the socket resubscribes with the new '
        'token', () {
      run((h) {
        h.subscribe(); // token "tok"
        expect(h.hub.channels, hasLength(1));

        h.storage.contact.save(contact(id: 2, pubsubToken: 'tok-B'));
        h.flush();
        h.repo.onSessionReset();
        h.channel.welcome();
        h.flush();

        expect(h.hub.channels, hasLength(2));
        expect(h.channel.sent.first['identifier'], contains('tok-B'));
      });
    });

    test('a reset that keeps the token does not reconnect', () {
      run((h) {
        h.subscribe();

        h.repo.onSessionReset();
        h.flush();

        expect(h.hub.channels, hasLength(1));
      });
    });

    test('a later drop reconnects with the NEW token', () {
      run((h) {
        h.subscribe();
        h.storage.contact.save(contact(id: 2, pubsubToken: 'tok-B'));
        h.flush();

        h.channel.serverClose(); // drop; the socket reads the token again
        h.flush();
        h.elapse(const Duration(seconds: 1));
        h.channel.welcome();
        h.flush();

        expect(h.channel.sent.first['identifier'], contains('tok-B'));
      });
    });
  });

  // SEC6
  group('hostile payloads', () {
    test('absurd created_at and ids do not stop later events', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        run((h) {
          h.subscribe();

          h.messageCreated({'id': 1, 'message_type': 1, 'created_at': 1e300});
          h.messageCreated({
            'id': 2,
            'message_type': 1,
            'created_at': 99999999999999999,
          });
          h.messageCreated({'id': 0, 'message_type': 1});
          h.messageCreated({'id': -4, 'message_type': 1});
          h.messageCreated({'id': 3, 'message_type': 1});

          expect(h.received.map((m) => m.id), [1, 2, 3]);
        });
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
    });

    test('the reconnect refetch swallows any error, even a non-typed one', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        run((h) {
          h.subscribe();
          h.service.messagesResult = StateError('poisoned');

          h.channel.serverClose();
          h.flush();
          h.elapse(const Duration(seconds: 1));
          h.channel.welcome();
          h.channel.confirm();
          h.flush();

          expect(
            h.errors.single.type,
            ChatwootClientExceptionType.GET_MESSAGES_FAILED,
          );
        });
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
    });
  });
}

/// A message DAO whose writes are visible only after a delay: `getMessage`
/// returns null right after `saveMessage` was called.
class _SlowDao extends InMemoryChatwootMessagesDao {
  int saved = 0;

  @override
  Future<void> saveMessage(ChatwootMessage message) async {
    saved++;
    await Future<void>.delayed(const Duration(seconds: 1));
    await super.saveMessage(message);
  }
}
