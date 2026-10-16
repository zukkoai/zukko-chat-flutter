import 'dart:async';

import 'package:zukko_chat_flutter/src/core/zukko_chat_callbacks.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/zukko_chat_repository.dart';
import 'package:zukko_chat_flutter/src/data/local/dao/zukko_chat_messages_dao.dart';
import 'package:zukko_chat_flutter/src/data/local/dao/single_store.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_contact.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_conversation.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_message.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session_api.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_action_data.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/zukko_chat_socket.dart';
import 'package:fake_async/fake_async.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_connection_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_http.dart';
import '../utils/fakes.dart';
import '../utils/fixtures.dart';

/// Repository + a REAL [ZukkoChatSocket] over [FakeChannel]s, under fake time:
/// frames in, callbacks out.
class _Harness {
  _Harness(this.async, {LocalStorage? store})
    : storage = store ?? LocalStorage.inMemory() {
    socket = ZukkoChatSocket(
      url: Uri.parse('wss://h/cable'),
      tokenProvider: () => storage.contact.get()?.pubsubToken,
      connect: hub.connect,
      backoff: (_) => const Duration(seconds: 1),
    );
    session = WidgetSession(
      api: WidgetSessionApi(dioWith(http), 'site'),
      storage: storage,
      now: () => async.getClock(DateTime(2026)).now(),
    );
    repo = ZukkoChatRepositoryImpl(
      session: session,
      clientService: service,
      localStorage: storage,
      socket: socket,
      streamCallbacks: ZukkoChatCallbacks(
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
        onConversationUpdated: (c) => conversations.add(c),
        onSessionReset: () => log.add('reset'),
        onConnectionStateChanged: (s) => states.add(s),
      ),
    );
  }

  final FakeAsync async;
  final service = FakeClientService();
  final LocalStorage storage;
  final hub = FakeSocketHub();

  /// What `POST /config` answers: the pubsub token of the contact.
  String configPubsub = 'tok';
  late final http = FakeHttpAdapter(
    (_) => (
      200,
      {
        'website_channel_config': {'auth_token': 'jwt-1'},
        'contact': {'id': 1, 'pubsub_token': configPubsub},
        'global_config': <String, Object?>{},
      },
    ),
  );
  late final WidgetSession session;
  final conversations = <ZukkoChatConversation>[];
  late final ZukkoChatSocket socket;
  late final ZukkoChatRepositoryImpl repo;

  final errors = <ZukkoChatException>[];
  final received = <ZukkoChatMessage>[];
  final updated = <ZukkoChatMessage>[];
  final delivered = <(ZukkoChatMessage, String)>[];
  final log = <String>[];
  var pings = 0;
  final states = <ZukkoChatConnectionState>[];

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

        expect(h.log, ['welcome', 'confirmed', 'retrieved ()']);
        expect(h.pings, 1);
        expect(h.states, [
          ZukkoChatConnectionState.connecting,
          ZukkoChatConnectionState.connected,
          ZukkoChatConnectionState.subscribed,
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
    test('called twice while subscribed: the connection is kept, events arrive once', () {
      run((h) {
        h.subscribe();
        final first = h.channel;
        h.repo.listenForEvents();
        h.flush();

        h.messageCreated({'id': 4, 'message_type': 1});

        expect(first.isClosedByClient, isFalse);
        expect(h.hub.channels, hasLength(1));
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
          ZukkoChatNewMessageRequest(content: 'x', echoId: 'e'),
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

    // S4: used to be `echoId!`. B5: it used to be reported as "received"
    test('own message without echo id (other device): neither received nor '
        'delivered, still stored', () {
      final errors = <Object>[];
      runZonedGuarded(() {
        run((h) {
          h.subscribe();

          h.messageCreated({'id': 3, 'message_type': 0});

          expect(h.received, isEmpty);
          expect(h.delivered, isEmpty);
          expect(h.storage.messages.getMessage(3), isNotNull);
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
        final repo = ZukkoChatRepositoryImpl(
          clientService: h.service,
          localStorage: h.storage,
          socket: h.socket,
          streamCallbacks: ZukkoChatCallbacks(
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
        h.configPubsub = 'stale'; // the server still hands out the same one
        h.storage.contact.save(contact(pubsubToken: 'stale'));
        h.flush();
        h.repo.listenForEvents();
        h.channel.welcome();
        h.channel.emit({'type': 'reject_subscription'});
        h.flush();
        h.elapse(const Duration(minutes: 2));

        expect(
          h.errors.single.type,
          ZukkoChatExceptionType.socketSubscriptionRejected,
        );
        expect(h.channel.presenceFrames, 0);
        expect(h.hub.channels, hasLength(1));
        expect(h.states.last, ZukkoChatConnectionState.closed);
      });
    });
  });

  group('refetch after reconnect (S11)', () {
    test('the first subscription and each reconnect refetch once', () {
      run((h) {
        h.service.messagesResult = [message(1), message(2)];
        h.subscribe();
        expect(h.service.getMessagesCalls, 1);
        expect(h.service.messageCursors.single.after, isNull); // no cursor yet

        for (var reconnect = 1; reconnect <= 2; reconnect++) {
          h.channel.serverClose();
          h.flush();
          h.elapse(const Duration(seconds: 1));
          h.channel.welcome();
          h.channel.confirm();
          h.flush();

          expect(h.service.getMessagesCalls, reconnect + 1);
        }
        expect(h.log.where((l) => l.startsWith('retrieved')), hasLength(2));
        expect(h.storage.messages.getMessages().map((m) => m.id), [1, 2]);
      });
    });

    test('a refetch failure is reported, not thrown', () {
      run((h) {
        h.service.messagesResult = failure(
          ZukkoChatExceptionType.getMessagesFailed,
        );
        h.subscribe();

        h.channel.serverClose();
        h.flush();
        h.elapse(const Duration(seconds: 1));
        h.channel.welcome();
        h.channel.confirm();
        h.flush();

        expect(h.errors.map((e) => e.type).toSet(), {
          ZukkoChatExceptionType.getMessagesFailed,
        });
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
          ZukkoChatConnectionState.backoff,
          ZukkoChatConnectionState.connecting,
          ZukkoChatConnectionState.connected,
          ZukkoChatConnectionState.subscribed,
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

    // D6: typing_off used to fire the stop callback even when not typing
    test('typing_off without a typing_on fires nothing', () {
      run((h) {
        h.subscribe();

        h.channel.event('conversation.typing_off', {});
        h.flush();

        expect(h.log, isEmpty);
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

  group('conversation events', () {
    test('resolved keeps the messages, stores the status, fires once', () {
      run((h) {
        h.subscribe(conversationId: 8);
        h.storage.messages.saveMessage(message(1));
        h.flush();

        h.channel.event('conversation.status_changed', {
          'id': 8,
          'inbox_id': 1,
          'status': 'resolved',
        });
        h.channel.event('conversation.updated', {
          'id': 8,
          'inbox_id': 1,
          'status': 'resolved',
        });
        h.flush();

        expect(h.log, ['resolved']);
        expect(h.storage.conversation.get()?.status, 'resolved');
        expect(h.storage.messages.getMessages(), hasLength(1));
        expect(h.conversations.map((c) => c.status), ['resolved', 'resolved']);
      });
    });

    test('another conversation resolving is ignored', () {
      run((h) {
        h.subscribe(conversationId: 8);

        h.channel.event('conversation.status_changed', {
          'id': 99,
          'status': 'resolved',
        });
        h.channel.event('conversation.updated', {'id': 99, 'status': 'open'});
        h.flush();

        expect(h.log, isEmpty);
        expect(h.conversations, isEmpty);
        expect(h.storage.conversation.get()?.id, 8);
      });
    });

    test('conversation.created is adopted; its messages are ours', () {
      run((h) {
        h.subscribe(conversationId: 8);

        h.channel.event('conversation.created', {
          'id': 9,
          'inbox_id': 1,
          'status': 'open',
        });
        h.flush();
        h.messageCreated({'id': 5, 'message_type': 1, 'conversation_id': 9});
        h.messageCreated({'id': 6, 'message_type': 1, 'conversation_id': 8});

        expect(h.storage.conversation.get()?.id, 9);
        expect(h.storage.conversation.get()?.status, 'open');
        expect(h.conversations.single.id, 9);
        expect(h.received.map((m) => m.id), [5]);
      });
    });

    test('a conversation of another inbox is ignored', () {
      run((h) {
        h.subscribe(conversationId: 8);

        h.channel.event('conversation.created', {
          'id': 9,
          'inbox_id': 2,
          'status': 'open',
        });
        h.flush();

        expect(h.storage.conversation.get()?.id, 8);
        expect(h.conversations, isEmpty);
      });
    });

    test('conversation.updated of the open one stores the new status', () {
      run((h) {
        h.subscribe(conversationId: 8);

        h.channel.event('conversation.updated', {
          'id': 8,
          'inbox_id': 1,
          'status': 'pending',
        });
        h.flush();

        expect(h.storage.conversation.get()?.status, 'pending');
        expect(h.conversations.single.status, 'pending');
      });
    });
  });

  group('realtime attachments', () {
    test('agent files arrive with the message', () {
      run((h) {
        h.subscribe();

        h.messageCreated({
          'id': 5,
          'message_type': 1,
          'attachments': [
            {'id': 1, 'file_type': 'image', 'data_url': 'https://h/a.png'},
          ],
        });

        expect(h.received.single.attachments, hasLength(1));
        expect(h.storage.messages.getMessage(5)?.attachments, hasLength(1));
      });
    });

    test('a malformed attachments value does not lose the message', () {
      run((h) {
        h.subscribe();

        h.messageCreated({'id': 5, 'message_type': 1, 'attachments': 'oops'});

        expect(h.received.single.id, 5);
        expect(h.received.single.attachments, isNull);
      });
    });
  });

  group('rejected subscription', () {
    void reject(_Harness h) {
      h.storage.contact.save(contact(pubsubToken: 'tok'));
      h.flush();
      h.repo.listenForEvents();
      h.channel.welcome();
      h.channel.emit({'type': 'reject_subscription'});
      h.elapse(const Duration(milliseconds: 10)); // Dio needs a timer tick
    }

    test('the same token: reported, socket stays closed', () {
      run((h) {
        reject(h);
        h.elapse(const Duration(seconds: 30)); // the slow retry comes at 60 s

        expect(h.http.calls, ['POST /api/v1/widget/config']);
        expect(
          h.errors.single.type,
          ZukkoChatExceptionType.socketSubscriptionRejected,
        );
        expect(h.socket.state, ZukkoChatConnectionState.closed);
        expect(h.hub.channels, hasLength(1));
      });
    });

    test('a new token reconnects', () {
      run((h) {
        h.configPubsub = 'fresh';
        reject(h);

        expect(h.errors, isEmpty);
        expect(h.hub.channels, hasLength(2));
        expect(h.socket.state, ZukkoChatConnectionState.connecting);
      });
    });

    test('refreshing too often ends in SESSION_EXPIRED, no loop', () {
      run((h) {
        reject(h);
        for (var i = 0; i < 3; i++) {
          h.repo.listenForEvents();
          h.channel.welcome();
          h.channel.emit({'type': 'reject_subscription'});
          h.elapse(const Duration(milliseconds: 10));
        }

        expect(
          h.errors.map((e) => e.type),
          contains(ZukkoChatExceptionType.sessionExpired),
        );
        expect(h.http.requests.length, WidgetSession.maxRefreshes);
      });
    });
  });

  group('session reset', () {
    test('tells the UI, then loads conversation and latest messages', () {
      run((h) {
        h.subscribe();
        h.service
          ..conversationResult = conversation(id: 3)
          ..messagesResult = [message(30)];

        h.session.listener.onReset!();
        h.flush();

        expect(h.log, ['reset', 'retrieved (30)']);
        expect(h.storage.conversation.get()?.id, 3);
        expect(h.service.messageCursors.last.after, isNull);
      });
    });
  });

  group('sendAction (S17)', () {
    test('writes the frame when subscribed', () {
      run((h) {
        h.subscribe();
        final before = h.channel.sent.length;

        h.repo.sendAction(ZukkoChatActionType.updatePresence);

        expect(h.channel.sent.length, before + 1);
      });
    });

    test('is a silent no-op without a connection', () {
      run((h) {
        expect(
          () => h.repo.sendAction(ZukkoChatActionType.updatePresence),
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
          contact: MemorySingleStore<ZukkoChatContact>(),
          conversation: MemorySingleStore<ZukkoChatConversation>(),
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
        h.session.listener.onReset!();
        h.channel.welcome();
        h.flush();

        expect(h.hub.channels, hasLength(2));
        expect(h.channel.sent.first['identifier'], contains('tok-B'));
      });
    });

    test('a reset that keeps the token does not reconnect', () {
      run((h) {
        h.subscribe();

        h.session.listener.onReset!();
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
            ZukkoChatExceptionType.getMessagesFailed,
          );
        });
      }, (e, s) => errors.add(e));
      expect(errors, isEmpty);
    });
  });
}

/// A message DAO whose writes are visible only after a delay: `getMessage`
/// returns null right after `saveMessage` was called.
class _SlowDao extends InMemoryZukkoChatMessagesDao {
  int saved = 0;

  @override
  Future<void> saveMessage(ZukkoChatMessage message) async {
    saved++;
    await Future<void>.delayed(const Duration(seconds: 1));
    await super.saveMessage(message);
  }
}
